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

#pragma once

#include "map/besieged_data.h"

namespace besieged
{
    void init(); // Must be called on map initialization. Checks for zones that may be affected by besieged state.

    std::shared_ptr<BesiegedData> GetBesiegedData();                                                     // Cached data with besieged map info
    void                          AdvancePhaseEnded(BESIEGED_STRONGHOLD strongholdId, bool intercepted); // Called by map server when a beastmen stronghold advance phase ends
    void                          HandleZMQMessage(uint8* data);                                         // Called whenever a ZMQ message is recieved from world server
} // namespace besieged
