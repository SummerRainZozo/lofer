// Starts the Lofer backend:  npm start   (or: node --env-file=.env src/server.ts)
import { createApp } from './app.ts';
import { createProvider } from './providers/index.ts';

const port = Number(process.env.PORT ?? 8787);
const provider = createProvider();
createApp(provider).listen(port, '127.0.0.1', () => {
  console.log(`Lofer backend on http://127.0.0.1:${port}  (Care Intelligence provider: ${provider.name})`);
});
