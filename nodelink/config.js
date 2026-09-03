// NodeLink v3 configuration for Lauffy.
// The official image already ships config.default.js. Extending it here keeps
// every upstream default while making the deployment-specific settings explicit.
import defaults from './config.default.js'

const integer = (value, fallback) => {
  const parsed = Number.parseInt(value ?? '', 10)
  return Number.isInteger(parsed) && parsed > 0 && parsed <= 65535 ? parsed : fallback
}

const boolean = (value, fallback) => {
  if (value == null || value === '') return fallback
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase())
}

export default {
  ...defaults,
  server: {
    ...defaults.server,
    host: process.env.NODELINK_SERVER_HOST || '0.0.0.0',
    port: integer(process.env.NODELINK_SERVER_PORT, 2333),
    // Docker Compose supplies this from NODELINK_PASSWORD; never add a real
    // password to this file.
    password: process.env.NODELINK_SERVER_PASSWORD || defaults.server.password,
  },
  logging: {
    ...defaults.logging,
    level: process.env.NODELINK_LOGGING_LEVEL || 'info',
  },
  sponsorblock: {
    ...defaults.sponsorblock,
    // Disabled by default for predictable playback; enable it explicitly in
    // .env after the base stack is working.
    enabled: boolean(process.env.NODELINK_SPONSORBLOCK_ENABLED, false),
  },
  // Keep the built-in NodeLink audio filters available through the Lavalink v4
  // player endpoints; Lauffy does not force filters on any guild.
  filters: {
    ...defaults.filters,
    enabled: { ...defaults.filters.enabled },
  },
}
