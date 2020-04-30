/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */
package org.zowe.apiml.util.http;

import lombok.experimental.UtilityClass;
import org.apache.http.Header;
import org.apache.http.HttpRequest;
import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.StringEntity;
import org.zowe.apiml.gatewayservice.SecurityUtils;
import org.zowe.apiml.util.config.ConfigReader;
import org.zowe.apiml.util.config.Credentials;

import java.io.IOException;
import java.net.URI;

@UtilityClass
public class HttpSecurityUtils {

    public static String getCookieForGateway() throws IOException {
        Credentials credentials = ConfigReader.environmentConfiguration().getCredentials();
        String user = credentials.getUser();
        String password = credentials.getPassword();
        URI uri = HttpRequestUtils
                .getUriFromGateway(SecurityUtils.GATEWAY_BASE_PATH.concat(SecurityUtils.GATEWAY_LOGIN_ENDPOINT));
        return getCookie(uri, user, password);
    }

    private static String getCookie(URI loginUrl, String user, String password) throws IOException {
        HttpPost request = new HttpPost(loginUrl);
        HttpClient client = HttpClientUtils.client();
        String credentials = String.format("{\"username\":\"%s\", \"password\":\"%s\"}", user, password);
        StringEntity payload = new StringEntity(credentials);
        request.setEntity(payload);
        request.setHeader("Content-type", "application/json");

        HttpResponse response = client.execute(request);
        Header cookie = response.getFirstHeader("Set-Cookie");
        if (cookie == null) {
            return null;
        }
        return response.getFirstHeader("Set-Cookie").getValue();
    }

    public static void addCookie(HttpRequest request, String cookie) {
        request.addHeader("Cookie", cookie);
    }
}
