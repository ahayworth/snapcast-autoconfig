const config = {
  host: '192.168.1.29',
  port: 1705,
  streams: [
    {
      id: 'bedroom',
      clients: ['bedroom'],
      priority: 1,
    },
    {
      id: 'bathroom',
      clients: ['bathroom'],
      priority: 1,
    },
    {
      id: 'mastersuite',
      clients: [
        'bedroom',
        'bathroom',
      ],
      priority: 2,
    },
    {
      id: 'kitchen',
      clients: ['kitchen'],
      priority: 1,
    },
    {
      id: 'livingroom',
      clients: ['livingroom'],
      priority: 1,
    },
    {
      id: 'greatroom',
      clients: [
        'kitchen',
        'livingroom'
      ],
      priority: 2,
    },
    {
      id: 'wholehouse',
      clients: [
        'bedroom',
        'bathroom',
        'kitchen',
        'livingroom',
      ],
      priority: 3,
    }
  ],
};

module.exports = config;
