/*
===========================================================================

Copyright (c) 2023 LandSandBoat Dev Teams

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see http://www.gnu.org/licenses/

===========================================================================
*/

#include "conquest_system.h"

#include "common/async.h"
#include "message_server.h"

/**
 * ConquestSystem both handles messages from map servers and
 * updates the database with the latest conquest data periodically.
 *
 * This class is guided by the following pattern:
 * - All public methods that may modify the database are enqueued in the task system.
 * - The task system processes tasks in its own thread
 * - Private methods are not guarded via the task system, but are only called from
 *   public methods, so we can assume that they are always called from the task system.
 */
ConquestSystem::ConquestSystem()
{
    submit([this](){
        sql = std::make_unique<SqlConnection>();
    });
}

bool ConquestSystem::handleMessage(const std::vector<uint8>& payload,
                                   in_addr                   from_addr,
                                   uint16                    from_port)
{
    const uint8 conquestMsgType = payload[1];
    if (conquestMsgType == CONQUESTMSGTYPE::CONQUEST_MAP2WORLD_GM_WEEKLY_UPDATE)
    {
        // updateWeekConquest already goes through task system
        updateWeekConquest();
        return true;
    }

    if (conquestMsgType == CONQUESTMSGTYPE::CONQUEST_MAP2WORLD_ADD_INFLUENCE_POINTS)
    {
        // clang-format off
        Async::getInstance()->submit([this, payload]()
        {
            int32  points = 0;
            uint32 nation = 0;
            uint8  region = 0;
            std::memcpy(&points, payload.data() + 2, sizeof(int32));
            std::memcpy(&nation, payload.data() + 6, sizeof(uint32));
            std::memcpy(&region, payload.data() + 10, sizeof(uint8));

            // We update influence but do not immediately send this update to all map servers
            // Influence updates are sent periodically via time_server instead.
            // It is okay for map servers to be eventually consistent.
            updateInfluencePoints(points, nation, (REGION_TYPE)region);
        });
        // clang-format on

        return true;
    }

    if (conquestMsgType == CONQUESTMSGTYPE::CONQUEST_MAP2WORLD_GM_CONQUEST_UPDATE)
    {
        // Convert from_addr to ip + port
        uint64 ipp = from_addr.s_addr;
        ipp |= (((uint64)from_port) << 32);

        // clang-format off
        submit([this, ipp]()
        {
            // Send influence data to the requesting map server
            sendInfluencesMsg(true, ipp);
        });
        // clang-format on

        return true;
    }

    ShowDebug(fmt::format("Message: unknown conquest type received: {} from {}:{}",
                          static_cast<uint8>(conquestMsgType),
                          from_addr.s_addr,
                          from_port));
    return false;
}

void ConquestSystem::updateWeekConquest()
{
    // clang-format off
    submit([this]()
    {
        TracyZoneScoped;

        // 1- Notify all zones that tally started
        sendTallyStartMsg();

        // 2- Do the actual db update
        const char* Query = "UPDATE conquest_system SET region_control = \
                                IF(sandoria_influence > bastok_influence AND sandoria_influence > windurst_influence AND \
                                sandoria_influence > beastmen_influence, 0, \
                                IF(bastok_influence > sandoria_influence AND bastok_influence > windurst_influence AND \
                                bastok_influence > beastmen_influence, 1, \
                                IF(windurst_influence > bastok_influence AND windurst_influence > sandoria_influence AND \
                                windurst_influence > beastmen_influence, 2, 3)));";

        int ret = sql->Query(Query);
        if (ret == SQL_ERROR)
        {
            ShowError("handleWeeklyUpdate() failed");
        }

        // 3- Send tally end Msg
        sendRegionControlsMsg(CONQUEST_WORLD2MAP_WEEKLY_UPDATE_END);
    });
    // clang-format on
}

void ConquestSystem::updateHourlyConquest()
{
    // clang-format off
    submit([this]()
    {
        sendInfluencesMsg(true);
    });
    // clang-format on
}

void ConquestSystem::updateVanaHourlyConquest()
{
    // clang-format off
    submit([this]()
    {
        sendInfluencesMsg(false);
    });
    // clang-format on
}

void ConquestSystem::sendTallyStartMsg()
{
    // 1- Send message to all zones. We are starting update.
    const std::size_t dataLen = 2 * sizeof(uint8);
    uint8             data[2 * sizeof(uint8) + sizeof(uint32)]{};

    // Create ZMQ message with header and no other payload
    ref<uint8>((uint8*)data, 0) = REGIONAL_EVT_MSG_CONQUEST;
    ref<uint8>((uint8*)data, 1) = CONQUEST_WORLD2MAP_WEEKLY_UPDATE_START;

    // Send to map
    zmq::message_t dataMsg = zmq::message_t(dataLen);
    memcpy(dataMsg.data(), data, dataLen);
    queue_message_broadcast(MSG_WORLD2MAP_REGIONAL_EVENT, &dataMsg);
}

void ConquestSystem::sendInfluencesMsg(bool shouldUpdateZones, uint64 ipp)
{
    auto influences = getRegionalInfluences();

    // Base length is the type + subtype + influence size
    const std::size_t headerLength = 2 * sizeof(uint8) + sizeof(std::size_t) + sizeof(bool);
    const std::size_t dataLen      = headerLength + sizeof(influence_t) * influences.size();
    const uint8*      data         = new uint8[dataLen];

    // Regional event type + conquest msg type
    ref<uint8>((uint8*)data, 0) = REGIONAL_EVT_MSG_CONQUEST;
    ref<uint8>((uint8*)data, 1) = CONQUEST_WORLD2MAP_INFLUENCE_POINTS;
    ref<uint8>((uint8*)data, 2) = shouldUpdateZones;

    // Influences controls array
    ref<std::size_t>((uint8*)data, 3) = influences.size();
    for (std::size_t i = 0; i < influences.size(); i++)
    {
        // Everything is offset by i*size of region control struct + headerLength
        const std::size_t start              = headerLength + i * sizeof(influence_t);
        ref<uint16>((uint8*)data, start)     = influences[i].sandoria_influence;
        ref<uint16>((uint8*)data, start + 2) = influences[i].bastok_influence;
        ref<uint16>((uint8*)data, start + 4) = influences[i].windurst_influence;
        ref<uint16>((uint8*)data, start + 6) = influences[i].beastmen_influence;
    }

    // 3- Create ZMQ Message and queue it
    zmq::message_t dataMsg = zmq::message_t(dataLen);
    memcpy(dataMsg.data(), data, dataLen);
    if (ipp == 0xFFFF)
    {
        queue_message_broadcast(MSG_WORLD2MAP_REGIONAL_EVENT, &dataMsg);
    }
    else
    {
        queue_message(ipp, MSG_WORLD2MAP_REGIONAL_EVENT, &dataMsg);
    }
}

void ConquestSystem::sendRegionControlsMsg(CONQUESTMSGTYPE msgType, uint64 ipp)
{
    // 2- Serialize regional controls with the following schema:
    // - REGIONALMSGTYPE
    // - CONQUESTMSGTYPE
    // - region controls array size
    // - For N elements we have:
    //      - current control (uint8)
    //      - prev control (uint8)
    auto regionControls = getRegionControls();

    // Header length is the type + subtype + region control size + size of the size_t
    const std::size_t headerLength = 2 * sizeof(uint8) + sizeof(std::size_t);
    const std::size_t dataLen      = headerLength + sizeof(region_control_t) * regionControls.size();
    const uint8*      data         = new uint8[dataLen];

    // Regional event type + conquest msg type
    ref<uint8>((uint8*)data, 0) = REGIONAL_EVT_MSG_CONQUEST;
    ref<uint8>((uint8*)data, 1) = msgType;

    // Region controls array
    ref<std::size_t>((uint8*)data, 2) = regionControls.size();
    for (std::size_t i = 0; i < regionControls.size(); i++)
    {
        // Everything is offset by i*size of region control struct + headerLength
        const std::size_t offset             = headerLength + sizeof(region_control_t) * i;
        ref<uint8>((uint8*)data, offset)     = regionControls[i].current;
        ref<uint8>((uint8*)data, offset + 1) = regionControls[i].prev;
    }

    // 3- Create ZMQ Message and queue it
    zmq::message_t dataMsg = zmq::message_t(dataLen);
    memcpy(dataMsg.data(), data, dataLen);

    if (ipp == 0xFFFF)
    {
        queue_message_broadcast(MSG_WORLD2MAP_REGIONAL_EVENT, &dataMsg);
    }
    else
    {
        queue_message(ipp, MSG_WORLD2MAP_REGIONAL_EVENT, &dataMsg);
    }
}

bool ConquestSystem::updateInfluencePoints(int points, unsigned int nation, REGION_TYPE region)
{
    if (region == REGION_TYPE::UNKNOWN)
    {
        return false;
    }

    std::string Query = "SELECT sandoria_influence, bastok_influence, windurst_influence, beastmen_influence FROM conquest_system WHERE region_id = %d;";

    int ret = sql->Query(Query.c_str(), static_cast<uint8>(region));

    if (ret == SQL_ERROR || sql->NextRow() != SQL_SUCCESS)
    {
        return false;
    }

    int influences[4] = {
        sql->GetIntData(0),
        sql->GetIntData(1),
        sql->GetIntData(2),
        sql->GetIntData(3),
    };

    if (influences[nation] == 5000)
    {
        return false;
    }

    auto lost = 0;
    for (auto i = 0u; i < 4; ++i)
    {
        if (i == nation)
        {
            continue;
        }

        auto loss = std::min<int>(points * influences[i] / (5000 - influences[nation]), influences[i]);
        influences[i] -= loss;
        lost += loss;
    }

    influences[nation] += lost;

    ret = sql->Query("UPDATE conquest_system SET sandoria_influence = %d, bastok_influence = %d, "
                     "windurst_influence = %d, beastmen_influence = %d WHERE region_id = %u;",
                     influences[0], influences[1], influences[2], influences[3], static_cast<uint8>(region));

    return ret != SQL_ERROR;
}

auto ConquestSystem::getRegionalInfluences() -> std::vector<influence_t> const
{
    const char* Query = "SELECT sandoria_influence, bastok_influence, windurst_influence, beastmen_influence FROM conquest_system;";

    int32 ret = sql->Query(Query);

    std::vector<influence_t> influences;
    if (ret != SQL_ERROR && sql->NumRows() != 0)
    {
        while (sql->NextRow() == SQL_SUCCESS)
        {
            influence_t influence{};
            influence.sandoria_influence = sql->GetIntData(0);
            influence.bastok_influence   = sql->GetIntData(1);
            influence.windurst_influence = sql->GetIntData(2);
            influence.beastmen_influence = sql->GetIntData(3);
            influences.emplace_back(influence);
        }
    }

    return influences;
}

auto ConquestSystem::getRegionControls() -> std::vector<region_control_t> const
{
    const char* Query = "SELECT region_control, region_control_prev FROM conquest_system;";

    int32 ret = sql->Query(Query);

    std::vector<region_control_t> controllers;
    if (ret != SQL_ERROR && sql->NumRows() != 0)
    {
        while (sql->NextRow() == SQL_SUCCESS)
        {
            region_control_t regionControl{};
            regionControl.current = sql->GetIntData(0);
            regionControl.prev    = sql->GetIntData(1);
            controllers.emplace_back(regionControl);
        }
    }

    return controllers;
}
