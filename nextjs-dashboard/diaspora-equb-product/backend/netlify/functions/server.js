/**
 * Netlify serverless function: wraps the Nest/Express app so all routes are handled.
 * Build the backend first (npm run build); dist/ is included via netlify.toml included_files.
 */
const path = require('path');
const serverless = require('serverless-http');

let handlerPromise;

exports.handler = async (event, context) => {
  if (!handlerPromise) {
    const vercelPath = path.join(__dirname, '../../dist/vercel.js');
    const { createApp } = require(vercelPath);
    const app = await createApp();
    handlerPromise = Promise.resolve(serverless(app));
  }
  const h = await handlerPromise;
  return h(event, context);
};
