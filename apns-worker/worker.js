export default {
  async fetch(request, env) {
    if (request.method != 'POST') {
      return statusResponse(405)
    }

    const contentType = request.headers.get('Content-Type') || ''

    if (! contentType.includes('application/json')) {
      return statusResponse(415)
    }

    const url = new URL(request.url)
    const payload = await request.json()

    if (url.pathname == '/register') {
      return registerDevice(request, env, payload)
    }

    if (isWebhookRequest(request, payload)) {
      if (payload.eventType == 'Test') {
        return statusResponse(202)
      }

      const devices = await fetchDevices(request, env)

      return handleWebhook(request, env, devices, payload)  
    }

    return statusResponse(400)
  },
}

function statusResponse(code) {
  return Response.json({
    status: code,
  }, {
    status: code,
    headers: {
      'X-Robots-Tag': 'noindex, nofollow',
    },
  });
}

function isWebhookRequest(request, payload) {
  const userAgent = request.headers.get('user-agent') || ''

  if (! userAgent.startsWith('Radarr')) {
    return false
  }

  if (! Object.hasOwn(payload, 'eventType') || ! payload.eventType) {
    return false
  }

  if (! Object.hasOwn(payload, 'instanceName')) {
    return false
  }

  return true
}

async function registerDevice(request, env, payload) {
  const userAgent = request.headers.get('user-agent') || ''

  if (! userAgent.includes('Ruddarr')) {
    return statusResponse(400)
  }

  const currentDevices = await env.RUDDARR.get(payload.account, { type: 'json' })
  const newDevices = new Set(currentDevices ?? [])

  newDevices.add(payload.token)

  await env.RUDDARR.put(payload.account, JSON.stringify(Array.from(newDevices)))

  return statusResponse(201)
}

async function fetchDevices(request, env) {
  const url = new URL(request.url)
  const account = url.pathname.replace('/', '')

  if (account.length < 32) {
    return false
  }

  if (! /^[0-9a-f_]+$/.test(account)) {
    return false
  }

  return await env.RUDDARR.get(account, { type: 'json' })
}

async function handleWebhook(request, env, devices, payload) {
  const alert = alertForPayload(payload)

  if (alert && devices) {
    const authorizationToken = await generateAuthorizationToken(env)

    // send notifications in parallel
    await Promise.all(devices.map(async (deviceToken) => {
      const result = await sendNotification(alert, authorizationToken, deviceToken)
      console.debug(result)
    }));  
  }

  return statusResponse(202)
}

async function sendNotification(alert, authorizationToken, deviceToken) {
  const host = 'https://api.sandbox.push.apple.com'
  const url = `${host}/3/device/${deviceToken}`

  const body = {
    aps: {
      alert: alert,
      sound: 'ping.aiff', // chime.aiff, bingbong.aiff
    },
  }

  const init = {
    method: 'POST',
    body: JSON.stringify(body),
    headers: {
      'content-type': 'application/json;charset=UTF-8',
      'authorization': `Bearer ${authorizationToken}`,
      'apns-topic': 'com.ruddarr',
      'apns-push-type': 'alert',
      'apns-priority': '5',
    },
  }

  const response = await fetch(url, init)

  const { headers } = response
  const apnsId = headers.get('apns-id') || ''

  if (response.status < 400) {
    return { success: true, apnsId, deviceToken }
  }

  const json = await response.json()
  const message = json?.reason ?? 'Unknown'

  console.error(`APNs returned status ${response.status}: ${message} (apnsId: ${apnsId}, deviceToken: ${deviceToken})`)

  return { success: false, message, apnsId, deviceToken }
}

async function generateAuthorizationToken(env) {
  const storedToken = await env.RUDDARR.get('$token')

  if (storedToken !== null) {
    return storedToken
  }

  const payload =  {
    iss: env.TEAMID,
    iat: Math.floor(Date.now() / 1000)
  }

  const header = {
    kid: env.KEYID,
    typ: 'JWT'
  }

  const algorithm = {
    name: 'ECDSA',
    namedCurve: 'P-256',
    hash: {
      name: 'SHA-256',
    }
  }

  const jwtHeader = textToBase64Url(JSON.stringify({ ...header, alg: 'ES256' }))
  const jwtPayload = textToBase64Url(JSON.stringify(payload))

  const key = await crypto.subtle.importKey(
    'pkcs8', pemToBinary(env.AUTHKEY), algorithm, true, ['sign']
  )

  const signature = await crypto.subtle.sign(
    algorithm, key, textToArrayBuffer(`${jwtHeader}.${jwtPayload}`)
  )

  const token = `${jwtHeader}.${jwtPayload}.${arrayBufferToBase64Url(signature)}`

  await env.RUDDARR.put('$token', token, { expirationTtl: 60 * 45 })

  return token
}

function alertForPayload(payload) {
  const instanceName = payload.instanceName ? payload.instanceName : 'Radarr'

  switch (payload.eventType) {
    case 'RuddarrTest':
      return {
        'title-loc-key': 'NOTIFICATION_TEST',
        'loc-key': 'NOTIFICATION_TEST_BODY',
      }
    case 'Health':
      return {
        'title-loc-key': 'NOTIFICATION_HEALTH',
        'title-loc-args': [instanceName],
        'body': payload.message,
      }
    case 'HealthRestored':
      return {
        'title-loc-key': 'NOTIFICATION_HEALTH_RESOLVED',
        'title-loc-args': [instanceName],
        'body': payload.message,
      }
    case 'MovieAdded':
      return {
        'title-loc-key': 'NOTIFICATION_MOVIE_ADDED',
        'title-loc-args': [instanceName],
        'loc-key': 'NOTIFICATION_MOVIE_ADDED_BODY',
        'loc-args': [payload.movie.title, payload.movie.year],
      }
    case 'Grab':
      return {
        'title-loc-key': 'NOTIFICATION_MOVIE_GRAB',
        'title-loc-args': [instanceName],
        'subtitle-loc-key': 'NOTIFICATION_MOVIE_GRAB_SUBTITLE',
        'subtitle-loc-args': [payload.movie.title, payload.movie.year],
        'loc-key': 'NOTIFICATION_MOVIE_GRAB_BODY',
        'loc-args': [payload.release.releaseTitle, payload.release.indexer],
      }
    case 'Download':
      return {
        'title-loc-key': 'NOTIFICATION_MOVIE_DOWNLOAD',
        'title-loc-args': [instanceName],
        'loc-key': 'NOTIFICATION_MOVIE_DOWNLOAD_BODY',
        'loc-args': [payload.movie.title, payload.movie.year],
      }
  }
}

/**
 * https://github.com/tsndr/cloudflare-worker-jwt
 */
function textToBase64Url(str) {
  const encoder = new TextEncoder()
  const charCodes = encoder.encode(str)
  const binaryStr = String.fromCharCode(...charCodes)

  return btoa(binaryStr).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function arrayBufferToBase64Url(arrayBuffer) {
  return arrayBufferToBase64String(arrayBuffer).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function arrayBufferToBase64String(arrayBuffer) {
  return btoa(bytesToByteString(new Uint8Array(arrayBuffer)))
}

function bytesToByteString(bytes) {
  let byteStr = ''

  for (let i = 0; i < bytes.byteLength; i++) {
      byteStr += String.fromCharCode(bytes[i])
  }

  return byteStr
}

export function byteStringToBytes(byteStr) {
  let bytes = new Uint8Array(byteStr.length)

  for (let i = 0; i < byteStr.length; i++) {
      bytes[i] = byteStr.charCodeAt(i)
  }

  return bytes
}

function textToArrayBuffer(str) {
  return byteStringToBytes(decodeURI(encodeURIComponent(str)))
}

function pemToBinary(pem) {
  return base64StringToArrayBuffer(pem.replace(/-+(BEGIN|END).*/g, '').replace(/\s/g, ''))
}

function base64StringToArrayBuffer(b64str) {
  return byteStringToBytes(atob(b64str)).buffer
}