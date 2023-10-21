﻿/*
===========================================================================

Copyright (c) 2010-2015 Darkstar Dev Teams

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

#pragma once

#include "besieged_system.h"
#include "common/mmo.h"
#include "common/socket.h"
#include "common/sql.h"
#include "conquest_system.h"
#include "message_handler.h"

#include <nonstd/jthread.hpp>
#include <zmq.hpp>
#include <zmq_addon.hpp>

class WorldServer;

void queue_message(uint64 ipp, MSGSERVTYPE type, zmq::message_t* extra, zmq::message_t* packet = nullptr);
void queue_message_broadcast(MSGSERVTYPE type, zmq::message_t* extra, zmq::message_t* packet = nullptr);

void message_server_init(WorldServer const& worldServer, const bool& requestExit);

void message_server_close();

struct message_server_wrapper_t
{
    message_server_wrapper_t(WorldServer const& worldServer, const std::atomic_bool& requestExit)
    : m_thread(std::make_unique<nonstd::jthread>(std::bind(message_server_init, std::ref(worldServer), std::ref(requestExit))))
    {
    }

    ~message_server_wrapper_t()
    {
        message_server_close();
    }

private:
    std::unique_ptr<nonstd::jthread> m_thread;
};
