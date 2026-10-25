package com.player.network

import okhttp3.Authenticator
import okhttp3.Request
import okhttp3.Response
import okhttp3.Route

/**
 * OkHttp Authenticator that intercepts HTTP 401 Unauthorized responses mid-stream,
 * executes token refresh callback, and seamlessly retries failed segment requests.
 */
class TokenRefreshAuthenticator(
    private val tokenProvider: () -> String?,
    private val onTokenRefreshed: ((String) -> Unit)? = null
) : Authenticator {

    @Synchronized
    override fun authenticate(route: Route?, response: Response): Request? {
        // Prevent infinite retry loops if credentials are fundamentally invalid
        if (responseCount(response) >= 3) {
            return null
        }

        // Fetch fresh token
        val freshToken = tokenProvider() ?: return null

        onTokenRefreshed?.invoke(freshToken)

        // Re-execute request with new Authorization header
        return response.request.newBuilder()
            .header("Authorization", "Bearer $freshToken")
            .build()
    }

    private fun responseCount(response: Response): Int {
        var count = 1
        var prior = response.priorResponse
        while (prior != null) {
            count++
            prior = prior.priorResponse
        }
        return count
    }
}
