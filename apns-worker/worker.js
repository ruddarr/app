// interruption-level = passive ?

export default {
  async fetch(request, env, context) {
    console.info(`URL: ${request.url}`)
    console.info(`User-Agent: ${request.headers.get('user-agent')}`)
    console.info(`CF-Connecting-IP: ${request.headers.get('cf-connecting-ip')}`)

    if (request.method != 'POST') {
      return statusResponse(405)
    }

    const contentType = request.headers.get('Content-Type') || ''

    if (! contentType.includes('application/json')) {
      return statusResponse(415)
    }

    const url = new URL(request.url)
    const payload = await request.json()

    console.info('Payload: ' + JSON.stringify(payload).replace(/\\/g, ''))

    if (url.pathname == '/register') {
      return registerDevice(request, env, payload)
    }

    if (isWebhookRequest(request, payload)) {
      if (payload.eventType == 'Test') {
        return statusResponse(202)
      }

      console.info(`Type: ${payload.eventType}`)

      if (payload.eventType == 'ManualInteractionRequired') {
        await sendDebugEmail(payload)
        return statusResponse(202)
      }

      const devices = await fetchDevices(request, env)

      return handleWebhook(env, devices, payload)
    }

    return statusResponse(400)
  },
}

function statusResponse(code) {
  console.info(`Response: ${code}`)

  return Response.json({
    status: code,
  }, {
    status: code,
    headers: {
      'X-Robots-Tag': 'noindex, nofollow',
    },
  })
}

function isWebhookRequest(request, payload) {
  const userAgent = request.headers.get('user-agent') || ''

  if (! userAgent.startsWith('Radarr')) {
    // return false (check Sonarr too)
  }

  if (! Object.hasOwn(payload, 'eventType') || ! payload.eventType) {
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
  const devices = new Set(currentDevices ?? [])

  if (devices.has(payload.token)) {
    return statusResponse(200)
  }

  devices.add(payload.token)
  await env.RUDDARR.put(payload.account, JSON.stringify(Array.from(devices)))

  return statusResponse(201)
}

async function deregisterDevice(account, token, env) {
  const currentDevices = await env.RUDDARR.get(account, { type: 'json' })
  const devices = new Set(currentDevices ?? [])

  if (devices.has(token)) {
    devices.delete(token)

    await env.RUDDARR.put(account, JSON.stringify(Array.from(devices)))
  }
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

async function handleWebhook(env, devices, payload) {
  const notification = buildNotificationPayload(payload)

  console.info('Notification: ' + JSON.stringify(notification).replace(/\\/g, ''))
  console.info('Devices: ' + JSON.stringify(devices).replace(/\\/g, ''))

  if (notification && devices) {
    const authorizationToken = await generateAuthorizationToken(env)
    console.info(`JWT: ${authorizationToken}`)

    // send notifications in parallel
    await Promise.all(devices.map(async (deviceToken) => {
      await sendNotification(notification, authorizationToken, deviceToken)
    }))
  }

  return statusResponse(202)
}

async function sendNotification(notification, authorizationToken, deviceToken, sandbox = false) {
  const host = sandbox
    ? 'https://api.sandbox.push.apple.com'
    : 'https://api.push.apple.com'

  const url = `${host}/3/device/${deviceToken}`

  const days = sandbox ? 2 : 14
  const dayInSeconds = 86400
  const now = Math.floor(Date.now() / 1000)

  const init = {
    method: 'POST',
    body: JSON.stringify(notification),
    headers: {
      'content-type': 'application/json;charset=UTF-8',
      'authorization': `Bearer ${authorizationToken}`,
      'apns-topic': 'com.ruddarr',
      'apns-push-type': 'alert',
      'apns-expiration': `${now + (dayInSeconds * days)}`,
    },
  }

  const response = await fetch(url, init)

  const { headers } = response

  const apnsId = (
    headers.get('apns-unique-id') ||
    headers.get('apns-id') ||
    ''
  ).toLowerCase()

  if (response.status < 400) {
    console.info(`APNs returned status ${response.status} (sandbox: ${+sandbox}, apnsId: ${apnsId}, deviceToken: ${deviceToken})`)

    return { success: true, apnsId, deviceToken }
  }

  const json = await response.json()
  const message = json?.reason ?? 'Unknown'

  console.error(`APNs returned status ${response.status}: ${message} (sandbox: ${+sandbox}, apnsId: ${apnsId}, deviceToken: ${deviceToken})`)

  if (response.status == 400 && message == 'BadDeviceToken') {
    if (! sandbox) {
      return sendNotification(notification, authorizationToken, deviceToken, true)
    }

    // deregisterDevice(deviceToken, env)
  }

  if (response.status == 410 && ['ExpiredToken', 'Unregistered'].includes(message)) {
    // deregisterDevice(deviceToken, env)
  }

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

function buildNotificationPayload(payload) {
  const instanceName = payload.instanceName?.trim().length > 0 ? payload.instanceName : '{Instance}'
  const isSeries = payload.hasOwnProperty('series')

  const type = isSeries ? 'SERIES' : 'MOVIE'
  const title = payload.series?.title ?? payload.movie?.title ?? '{Title}'
  const year = payload.series?.year ?? payload.movie?.year ?? '{Year}'
  const threadId = payload.series?.tvdbId ?? payload.movie?.tmdbId

  const episodes = payload.episodes?.length
  const episode = payload.episodes?.[0].episodeNumber
  const season = payload.episodes?.[0].seasonNumber

  switch (payload.eventType) {
    case 'RuddarrTest':
      return {
        aps: {
          'alert': {
            'title-loc-key': 'NOTIFICATION_TEST',
            'loc-key': 'NOTIFICATION_TEST_BODY',
          },
          'sound': 'ping.aiff',
          'relevance-score': 0.2,
        },
      }

    case 'ApplicationUpdate':
      return {
        aps: {
          'alert': {
            'title-loc-key': 'NOTIFICATION_APPLICATION_UPDATE',
            'title-loc-args': [instanceName],
            'body': payload.message,
          },
          'sound': 'ping.aiff',
          'relevance-score': 1.0,
        },
      }

    case 'Health':
      return {
        aps: {
          'alert': {
            'title-loc-key': 'NOTIFICATION_HEALTH',
            'title-loc-args': [instanceName],
            'body': payload.message,
          },
          'sound': 'ping.aiff',
          'thread-id': `health:${payload.type}`,
          'relevance-score': 0.8,
        },
      }

    case 'HealthRestored':
      return {
        aps: {
          'alert': {
            'title-loc-key': 'NOTIFICATION_HEALTH_RESTORED',
            'title-loc-args': [instanceName],
            'body': payload.message,
          },
          'sound': 'ping.aiff',
          'thread-id': `health:${payload.type}`,
          'relevance-score': 1.0,
        },
      }

    case 'MovieAdded':
      return {
        aps: {
          'alert': {
            'title-loc-key': 'NOTIFICATION_MOVIE_ADDED',
            'title-loc-args': [instanceName],
            'loc-key': 'NOTIFICATION_MOVIE_ADDED_BODY',
            'loc-args': [title, year],
          },
          'sound': 'ping.aiff',
          'thread-id': `movie:${threadId}`,
          'relevance-score': 0.6,
        },
        deeplink: `ruddarr://movies/open/${payload.movie?.id}`,
      }

    case 'SeriesAdd':
      return {
        aps: {
          'alert': {
            'title-loc-key': 'NOTIFICATION_SERIES_ADDED',
            'title-loc-args': [instanceName],
            'loc-key': 'NOTIFICATION_SERIES_ADDED_BODY',
            'loc-args': [title, year],
          },
          'sound': 'ping.aiff',
          'thread-id': `series:${threadId}`,
          'relevance-score': 0.6,
        },
        // deeplink: `ruddarr://series/open/${payload.series?.id}`,
      }

    case 'Grab':
      const releaseTitle = payload.release.releaseTitle.replace('.', ' ')
      const indexerName = payload.release.indexer.replace(' (Prowlarr)', '')

      if (! isSeries) {
        return {
          aps: {
            'alert': {
              'title-loc-key': 'NOTIFICATION_MOVIE_GRAB',
              'title-loc-args': [instanceName],
              'subtitle-loc-key': 'NOTIFICATION_MOVIE_GRAB_SUBTITLE',
              'subtitle-loc-args': [title, year],
              'loc-key': 'NOTIFICATION_MOVIE_GRAB_BODY',
              'loc-args': [releaseTitle, indexerName],
            },
            'sound': 'ping.aiff',
            'thread-id': `movie:${threadId}`,
            'relevance-score': 0.8,
          },
          deeplink: `ruddarr://movies/open/${payload.movie?.id}`,
        }
      }

      return {
        aps: {
          'alert': {
            'title-loc-key': episodes > 1 ? 'NOTIFICATION_EPISODES_GRAB' : 'NOTIFICATION_EPISODE_GRAB',
            'title-loc-args': [instanceName, episodes],
            'subtitle-loc-key': 'NOTIFICATION_EPISODES_GRAB_SUBTITLE',
            'subtitle-loc-args': [title, season],
            'loc-key': 'NOTIFICATION_EPISODES_GRAB_BODY',
            'loc-args': [releaseTitle, indexerName],
          },
          'sound': 'ping.aiff',
          'thread-id': `series:${threadId}`,
          'relevance-score': 0.8,
        },
        // deeplink: `ruddarr://series/open/${payload.series?.id}`,
      }

    case 'Download':
      const subtype = payload.isUpgrade ? 'UPGRADE' : 'DOWNLOAD'

      if (! isSeries) {
        return {
          aps: {
            'alert': {
              'title-loc-key': `NOTIFICATION_MOVIE_${subtype}`,
              'title-loc-args': [instanceName],
              'loc-key': 'NOTIFICATION_MOVIE_DOWNLOAD_BODY',
              'loc-args': [title, year],
            },
            'sound': 'ping.aiff',
            'thread-id': `movie:${threadId}`,
            'relevance-score': 1.0,
          },
          deeplink: `ruddarr://movies/open/${payload.movie?.id}`,
        }
      }

      if (episodes === 1) {
        return {
          aps: {
            'alert': {
              'title-loc-key': `NOTIFICATION_EPISODE_${subtype}`,
              'title-loc-args': [instanceName],
              'loc-key': 'NOTIFICATION_EPISODE_DOWNLOAD_BODY',
              'loc-args': [title, season, episode],
            },
            'sound': 'ping.aiff',
            'thread-id': `series:${threadId}`,
            'relevance-score': 1.0,
          },
          // deeplink: `ruddarr://series/open/${payload.series?.id}`,
        }
      }

      return {
        aps: {
          'alert': {
            'title-loc-key': `NOTIFICATION_EPISODES_${subtype}`,
            'title-loc-args': [instanceName, episodes],
            'loc-key': 'NOTIFICATION_EPISODES_DOWNLOAD_BODY',
            'loc-args': [title, season.toString()],
          },
          'sound': 'ping.aiff',
          'thread-id': `series:${threadId}`,
          'relevance-score': 1.0,
        },
        // deeplink: `ruddarr://series/open/${payload.series?.id}`,
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

async function sendDebugEmail(payload) {
  await fetch('https://api.postmarkapp.com/email', {
    method: 'POST',
    headers: {
      'accept': 'application/json',
      'content-type': 'application/json;charset=UTF-8',
      'x-postmark-server-token': '8ec6187d-5c62-460e-9293-2a9cbe4f8760',
    },
    body: JSON.stringify({
      'From': 'worker@till.im',
      'To': 'ruddarr@icloud.com',
      'Subject': 'ManualInteractionRequired',
      'TextBody': JSON.stringify(payload, null, 4)
    }),
  });
}
