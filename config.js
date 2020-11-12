const config = {
  host: '192.168.1.29',
  port: 1705,
  streams: [
    {
      id: 'Airplay - Master Bedroom',
      clients: ['Master Bedroom'],
      priority: 1,
    },
    {
      id: 'Airplay - Master Bathroom',
      clients: ['Master Bathroom'],
      priority: 1,
    },
    {
      id: 'Airplay - Master Suite',
      clients: [
        'Master Bedroom',
        'Master Bathroom',
      ],
      priority: 2,
    },
    {
      id: 'Airplay - Kitchen',
      clients: ['Kitchen'],
      priority: 1,
    },
    {
      id: 'Airplay - Living Room Speakers',
      clients: ['Living Room Speakers'],
      priority: 1,
    },
    {
      id: 'Airplay - Great Room',
      clients: [
        'Kitchen',
        'Living Room Speakers'
      ],
      priority: 2,
    },
    {
      id: 'Airplay - Whole House',
      clients: [
        'Master Bedroom',
        'Master Bathroom',
        'Kitchen',
        'Living Room Speakers',
      ],
      priority: 3,
    }
  ],
};

module.exports = config;
