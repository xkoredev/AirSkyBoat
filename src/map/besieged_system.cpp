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

#include "besieged_system.h"

#include "common/settings.h"
#include "map.h"
#include "utils/zoneutils.h"

namespace besieged
{
    // Hardcoded map of beastmen stronghold to advance zone id
    static const std::map<BESIEGED_STRONGHOLD, uint16> strongholdToZoneId =
    {
        { BESIEGED_STRONGHOLD::MAMOOK, 52 },
        { BESIEGED_STRONGHOLD::HALVUNG, 51 },
        { BESIEGED_STRONGHOLD::ARRAPAGO, 52 },
    };

    static std::shared_ptr<BesiegedData> besiegedData;

    std::shared_ptr<BesiegedData> GetBesiegedData()
    {
        if (besiegedData == nullptr)
        {
            besiegedData = std::make_shared<BesiegedData>(sql);
        }

        return besiegedData;
    }

    void keepZonesAwakeIfNecessary()
    {
        auto besiegedData = GetBesiegedData();
        for (auto strongholdId : { BESIEGED_STRONGHOLD::MAMOOK, BESIEGED_STRONGHOLD::HALVUNG, BESIEGED_STRONGHOLD::ARRAPAGO })
        {
            auto strongholdInfo = besiegedData->getBeastmenStrongholdInfo(strongholdId);
            if (strongholdInfo.orders == BEASTMEN_BESIEGED_ORDERS::ADVANCE)
            {
                // Keep the respective besieged zone awake for 5 minutes.
                // This is more than enough since we continue to keep zones awake
                // as long as world sends messages that the stronghold is in advance phase.
                auto zoneId = strongholdToZoneId.at(strongholdId);
                auto duration = std::chrono::minutes(5);
                zoneutils::GetZone(zoneId)->SetTickWhileEmpty(duration);
            }
        }
    }

    /**
     * Should be called on map initialization
    */
    void init()
    {
        // With initial data, check if any zones need to be kept active
        // due to their besieged state
        DebugBesieged("Initializing Besieged System")
        keepZonesAwakeIfNecessary();
    }

    /**
     * Called when stronghold updates are received from the world server
     */
    void HandleStrongholdUpdate(std::vector<stronghold_info_t> const& strongHoldInfos)
    {
        TracyZoneScoped;

        // Update the besieged data cache
        auto besiegedData = GetBesiegedData();
        besiegedData->updateStrongholdInfos(strongHoldInfos);

        // Any zones that are in advance phase should be kept awake
        keepZonesAwakeIfNecessary();

        DebugBesieged("Received besieged Stronghold Data:");
        for (auto line : besiegedData->getFormattedData())
        {
            DebugBesieged(line);
        }
    }

    /**
     * HandleZMQMessage is called by message_server when a besieged ZMQ message is receieved
     */
    void HandleZMQMessage(uint8* data)
    {
        uint8 subtype = ref<uint8>(data, 1);
        switch (subtype)
        {
            case BESIEGED_WORLD2MAP_STRONGHOLD_INFO:
            {
                const std::size_t headerLength    = 2 * sizeof(uint8);
                std::size_t       size            = ref<std::size_t>(data, 2);
                auto              strongholdInfos = std::vector<stronghold_info_t>(size);
                for (std::size_t i = 0; i < size; i++)
                {
                    const std::size_t start = headerLength + sizeof(size_t) + i * sizeof(stronghold_info_t);

                    stronghold_info_t strongholdInfo;
                    strongholdInfo.strongholdId          = (BESIEGED_STRONGHOLD)ref<uint8>(data, start);
                    strongholdInfo.orders                = (BEASTMEN_BESIEGED_ORDERS)ref<uint8>(data, start + 1);
                    strongholdInfo.strongholdLevel       = (STRONGHOLD_LEVEL)ref<uint8>(data, start + 2);
                    strongholdInfo.forces                = ref<float>(data, start + 3);
                    strongholdInfo.mirrors               = ref<uint8>(data, start + 7);
                    strongholdInfo.prisoners             = ref<uint8>(data, start + 8);
                    strongholdInfo.ownsAstralCandescence = ref<uint8>(data, start + 9);
                    strongholdInfo.consecutiveDefeats    = ref<uint32>(data, start + 10);

                    strongholdInfos[i] = strongholdInfo;
                }

                HandleStrongholdUpdate(strongholdInfos);
                break;
            }
            default:
            {
                ShowError("Unknown besieged message subtype %d", subtype);
            }
        }
    }
} // namespace besieged
