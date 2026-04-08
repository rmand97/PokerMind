import http from 'k6/http';
import { check, sleep } from 'k6';

// Configure via BASE_URL env var.
// Defaults to the local dev server so you can run against `mix phx.server`.
const BASE_URL = __ENV.BASE_URL || 'http://localhost:4000';

export const options = {
  scenarios: {
    steady_load: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '10s', target: 10 }, // Ramp up to 10 virtual users
        { duration: '30s', target: 10 }, // Hold at 10 virtual users
        { duration: '5s', target: 0 },   // Ramp back down
      ],
    },
  },
  thresholds: {
    // 95th percentile of all home page requests must be under 500ms
    'http_req_duration{name:GET /}': ['p(95)<500'],
    // Less than 1% of all requests may fail
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const res = http.get(`${BASE_URL}/`, {
    tags: { name: 'GET /' },
  });

  check(res, {
    'GET / returns 200': (r) => r.status === 200,
    'GET / has a response body': (r) => r.body && r.body.length > 0,
  });

  sleep(1);
}
