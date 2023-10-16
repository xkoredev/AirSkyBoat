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

xi.besieged.waves =
{
  [xi.besieged.STRONGHOLD.MAMOOL] =
  {
    npcOffset = 16986432,
    npcCount = 78,
    zone = 51,
  },
  [xi.besieged.STRONGHOLD.HALVUNG] =
  {
    npcOffset = 16986511,
    npcCount = 75,
    zone = 51,
  },
  [xi.besieged.STRONGHOLD.ARRAPAGO] =
  {
    npcOffset = 16990508,
    npcCount = 82,
    zone = 52,
    pos = {x = 68.3, y = -33.8, z = 625, h = 80},
  },
}