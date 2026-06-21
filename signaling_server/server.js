const { WebSocketServer } = require('ws');

const port = process.env.PORT || 8080;
const wss = new WebSocketServer({ port });

const rooms = new Map();

function generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  for (let i = 0; i < 4; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return code;
}

wss.on('connection', (ws) => {
  ws.roomCode = null;
  ws.isHost = false;

  ws.on('message', (message) => {
    try {
      const msg = JSON.parse(message);
      
      switch (msg.type) {
        case 'host':
          let roomCode = generateRoomCode();
          while (rooms.has(roomCode)) {
            roomCode = generateRoomCode();
          }
          
          ws.roomCode = roomCode;
          ws.isHost = true;
          
          rooms.set(roomCode, { host: ws, client: null });
          ws.send(JSON.stringify({ type: 'hosted', room: roomCode }));
          console.log(`Room created: ${roomCode}`);
          break;

        case 'join':
          const targetRoom = msg.room ? msg.room.toUpperCase() : '';
          if (!rooms.has(targetRoom)) {
            ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
            return;
          }
          
          const room = rooms.get(targetRoom);
          if (room.client) {
            ws.send(JSON.stringify({ type: 'error', message: 'Room is full' }));
            return;
          }
          
          ws.roomCode = targetRoom;
          ws.isHost = false;
          room.client = ws;
          
          room.host.send(JSON.stringify({ type: 'peer_connected' }));
          ws.send(JSON.stringify({ type: 'joined', room: targetRoom }));
          console.log(`Peer joined room: ${targetRoom}`);
          break;

        case 'signal':
          if (!ws.roomCode || !rooms.has(ws.roomCode)) return;
          const currentRoom = rooms.get(ws.roomCode);
          const recipient = ws.isHost ? currentRoom.client : currentRoom.host;
          
          if (recipient && recipient.readyState === 1) {
            recipient.send(JSON.stringify({ type: 'signal', data: msg.data }));
          }
          break;
      }
    } catch (err) {
      console.error('Error handling message:', err);
    }
  });

  ws.on('close', () => {
    if (ws.roomCode && rooms.has(ws.roomCode)) {
      const room = rooms.get(ws.roomCode);
      if (ws.isHost) {
        if (room.client) {
          room.client.send(JSON.stringify({ type: 'peer_disconnected' }));
          room.client.roomCode = null;
        }
        rooms.delete(ws.roomCode);
        console.log(`Room closed (host left): ${ws.roomCode}`);
      } else {
        if (room.host) {
          room.host.send(JSON.stringify({ type: 'peer_disconnected' }));
        }
        room.client = null;
        console.log(`Client left room: ${ws.roomCode}`);
      }
    }
  });
});

console.log(`Signaling server running on port ${port}`);
