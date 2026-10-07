// Starts the Lofer backend:  npm start   (reads backend/.env when it exists)
import { createApp } from './app.ts';
import { createProvider } from './providers/index.ts';

const port = Number(process.env.PORT ?? 8787);
const provider = createProvider();
createApp(provider).listen(port, '127.0.0.1', () => {
  const model = 'model' in provider ? ` · model ${String((provider as { model: string }).model)}` : '';
  console.log(`Lofer backend on http://127.0.0.1:${port}  (Care Intelligence provider: ${provider.name}${model})`);
});
