// K6 Load Test - Scripts API
// Tests API performance under various load conditions

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const scriptCreationTime = new Trend('script_creation_duration');
const scriptFetchTime = new Trend('script_fetch_duration');
const totalRequests = new Counter('total_requests');

// Test configuration
export const options = {
  stages: [
    { duration: '1m', target: 10 },   // Ramp up to 10 users
    { duration: '3m', target: 50 },   // Ramp up to 50 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 50 },   // Ramp down to 50
    { duration: '1m', target: 0 },    // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.05'],   // Error rate must be below 5%
    'errors': ['rate<0.1'],           // Custom error rate below 10%
  },
};

// Base URL
const BASE_URL = __ENV.API_URL || 'http://localhost:3000';

// Test data
let accessToken = '';
let scriptIds = [];

// Setup - runs once per VU
export function setup() {
  // Create test user and get token
  const signupRes = http.post(`${BASE_URL}/api/auth/signup`, JSON.stringify({
    email: `loadtest_${Date.now()}_${Math.random().toString(36).substring(7)}@example.com`,
    password: 'LoadTest123!',
    displayName: 'Load Test User',
  }), {
    headers: { 'Content-Type': 'application/json' },
  });

  const token = signupRes.json('session.accessToken');
  console.log('Setup complete, token obtained');

  return { token };
}

// Main test function
export default function (data) {
  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${data.token}`,
    },
  };

  totalRequests.add(1);

  group('Script API Tests', () => {
    // Test 1: Create Script
    group('Create Script', () => {
      const payload = JSON.stringify({
        title: `Load Test Script ${__VU}-${__ITER}`,
        content: 'This is a test script for load testing. '.repeat(100),
        category: 'presentation',
        tags: ['load-test', 'performance'],
      });

      const createStart = Date.now();
      const createRes = http.post(`${BASE_URL}/api/scripts`, payload, params);
      const createDuration = Date.now() - createStart;

      scriptCreationTime.add(createDuration);

      const createCheck = check(createRes, {
        'create status is 201': (r) => r.status === 201,
        'create has script id': (r) => r.json('id') !== undefined,
        'create duration < 1s': () => createDuration < 1000,
      });

      if (!createCheck) {
        errorRate.add(1);
      } else {
        errorRate.add(0);
        scriptIds.push(createRes.json('id'));
      }
    });

    sleep(0.5);

    // Test 2: Fetch Scripts List
    group('Fetch Scripts', () => {
      const fetchStart = Date.now();
      const fetchRes = http.get(`${BASE_URL}/api/scripts`, params);
      const fetchDuration = Date.now() - fetchStart;

      scriptFetchTime.add(fetchDuration);

      const fetchCheck = check(fetchRes, {
        'fetch status is 200': (r) => r.status === 200,
        'fetch has array': (r) => Array.isArray(r.json()),
        'fetch duration < 500ms': () => fetchDuration < 500,
      });

      if (!fetchCheck) {
        errorRate.add(1);
      } else {
        errorRate.add(0);
      }
    });

    sleep(0.5);

    // Test 3: Update Script (if we have one)
    if (scriptIds.length > 0) {
      group('Update Script', () => {
        const scriptId = scriptIds[Math.floor(Math.random() * scriptIds.length)];
        const payload = JSON.stringify({
          title: `Updated Script ${__VU}-${__ITER}`,
          content: 'Updated content for load testing. '.repeat(100),
        });

        const updateRes = http.put(`${BASE_URL}/api/scripts/${scriptId}`, payload, params);

        const updateCheck = check(updateRes, {
          'update status is 200': (r) => r.status === 200,
          'update duration < 800ms': (r) => r.timings.duration < 800,
        });

        if (!updateCheck) {
          errorRate.add(1);
        } else {
          errorRate.add(0);
        }
      });

      sleep(0.3);
    }

    // Test 4: Get Single Script
    if (scriptIds.length > 0) {
      group('Get Single Script', () => {
        const scriptId = scriptIds[Math.floor(Math.random() * scriptIds.length)];
        const getRes = http.get(`${BASE_URL}/api/scripts/${scriptId}`, params);

        const getCheck = check(getRes, {
          'get status is 200': (r) => r.status === 200,
          'get has title': (r) => r.json('title') !== undefined,
          'get duration < 300ms': (r) => r.timings.duration < 300,
        });

        if (!getCheck) {
          errorRate.add(1);
        } else {
          errorRate.add(0);
        }
      });
    }

    sleep(1);
  });
}

// Teardown - runs once after all VUs complete
export function teardown(data) {
  console.log('Load test complete');
  console.log(`Total script IDs created: ${scriptIds.length}`);
}

// Run this test with:
// k6 run scripts-api.js
// k6 run --vus 50 --duration 5m scripts-api.js
// k6 run scripts-api.js --out json=results.json
