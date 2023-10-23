xi = xi or {}
xi.besieged = xi.besieged or {}

xi.besieged.STRONGHOLD =
{
    ALZHABI = 0,
    MAMOOL = 1,
    HALVUNG = 2,
    ARRAPAGO = 3
}

xi.besieged.ALZHABI_ORDERS =
{
    DEFENSE = 0x00,
    INTERCEPT = 0x01,
    INFILTRATE = 0x02,
}

xi.besieged.BEASTMEN_ORDERS =
{
    TRAIN = 0x00,
    ADVANCE = 0x01,
    ATTACK = 0x02,
    RETREAT = 0x03,
    DEFEND = 0x04,
    PREPARE = 0x05,
}

-- Zones that should receieve a message when Besieged state changes
xi.besieged.msgZones =
{
    xi.zone.AHT_URHGAN_WHITEGATE,
    xi.zone.AL_ZAHBI,
    xi.zone.ARRAPOGO_REEF,
    xi.zone.AYDEEWA_SUBTERRANE,
    xi.zone.BHAFLAU_THICKETS,
    xi.zone.CAEDARVA_MIRE,
    xi.zone.HALVUNG,
    xi.zone.MAMOOK,
    xi.zone.MOUNT_ZHAYOLM,
    xi.zone.WAJAOM_WOODLANDS,
}
