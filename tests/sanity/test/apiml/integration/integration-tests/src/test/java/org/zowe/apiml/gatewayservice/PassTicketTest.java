/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */
package org.zowe.apiml.gatewayservice;

import io.restassured.RestAssured;
import lombok.extern.slf4j.Slf4j;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.zowe.apiml.security.common.ticket.TicketRequest;
import org.zowe.apiml.security.common.ticket.TicketResponse;
import org.zowe.apiml.util.config.ConfigReader;
import org.zowe.apiml.util.config.DiscoverableClientConfiguration;
import org.zowe.apiml.util.config.EnvironmentConfiguration;
import org.zowe.apiml.util.config.GatewayServiceConfiguration;

import static io.restassured.RestAssured.given;
import static io.restassured.http.ContentType.JSON;
import static org.apache.http.HttpStatus.*;
import static org.hamcrest.CoreMatchers.containsString;
import static org.hamcrest.CoreMatchers.equalTo;
import static org.hamcrest.core.Is.is;
import static org.junit.Assert.assertEquals;
import static org.zowe.apiml.gatewayservice.SecurityUtils.*;
import static org.zowe.apiml.passticket.PassTicketService.DefaultPassTicketImpl.UNKNOWN_APPLID;

@Slf4j
public class PassTicketTest {

    private final static EnvironmentConfiguration ENVIRONMENT_CONFIGURATION = ConfigReader.environmentConfiguration();
    private final static GatewayServiceConfiguration GATEWAY_SERVICE_CONFIGURATION =
        ENVIRONMENT_CONFIGURATION.getGatewayServiceConfiguration();
    private final static DiscoverableClientConfiguration DISCOVERABLE_CLIENT_CONFIGURATION =
        ENVIRONMENT_CONFIGURATION.getDiscoverableClientConfiguration();

    private final static String SCHEME = GATEWAY_SERVICE_CONFIGURATION.getScheme();
    private final static String HOST = GATEWAY_SERVICE_CONFIGURATION.getHost();
    private final static int PORT = GATEWAY_SERVICE_CONFIGURATION.getPort();
    private final static String USERNAME = ENVIRONMENT_CONFIGURATION.getCredentials().getUser();
    private final static String APPLICATION_NAME = DISCOVERABLE_CLIENT_CONFIGURATION.getApplId();
    private final static String DISCOVERABLECLIENT_PASSTICKET_BASE_PATH = "/api/v1/dcpassticket";
    private final static String DISCOVERABLECLIENT_BASE_PATH = "/api/v1/discoverableclient";
    private final static String PASSTICKET_TEST_ENDPOINT = "/passticketTest";
    private final static String TICKET_ENDPOINT = "/api/v1/gateway/auth/ticket";
    private final static String COOKIE = "apimlAuthenticationToken";

    @BeforeEach
    public void setUp() {
        RestAssured.port = PORT;
        RestAssured.useRelaxedHTTPSValidation();
        RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
    }


    /*
     * /ticket endpoint tests
     */

    @Test
    public void doTicketWithInvalidMethod() {
        String expectedMessage = "Authentication method 'GET' is not supported for URL '" + TICKET_ENDPOINT + "'";

        RestAssured.config = RestAssured.config().sslConfig(getConfiguredSslConfig());
        TicketRequest ticketRequest = new TicketRequest(APPLICATION_NAME);

        given()
            .contentType(JSON)
            .body(ticketRequest)
        .when()
            .get(String.format("%s://%s:%d%s", SCHEME, HOST, PORT, TICKET_ENDPOINT))
        .then()
            .statusCode(is(SC_METHOD_NOT_ALLOWED))
            .body("messages.find { it.messageNumber == 'ZWEAG101E' }.messageContent", equalTo(expectedMessage));
    }

    @Test
    public void doTicketWithoutCertificate() {
        String jwt = gatewayToken();
        TicketRequest ticketRequest = new TicketRequest(APPLICATION_NAME);

        given()
            .contentType(JSON)
            .body(ticketRequest)
            .cookie(COOKIE, jwt)
        .when()
            .post(String.format("%s://%s:%d%s", SCHEME, HOST, PORT, TICKET_ENDPOINT))
        .then()
            .statusCode(is(SC_FORBIDDEN));
    }

    @Test
    public void doTicketWithoutToken() {
        String expectedMessage = "No authorization token provided for URL '" + TICKET_ENDPOINT + "'";

        RestAssured.config = RestAssured.config().sslConfig(getConfiguredSslConfig());
        TicketRequest ticketRequest = new TicketRequest(APPLICATION_NAME);

        given()
            .contentType(JSON)
            .body(ticketRequest)
        .when()
            .post(String.format("%s://%s:%d%s", SCHEME, HOST, PORT, TICKET_ENDPOINT))
        .then()
            .statusCode(is(SC_UNAUTHORIZED))
            .body("messages.find { it.messageNumber == 'ZWEAG131E' }.messageContent", equalTo(expectedMessage));
    }

    @Test
    public void doTicketWithInvalidCookie() {
        String jwt = "invalidToken";
        String expectedMessage = "Token is not valid for URL '" + TICKET_ENDPOINT + "'";

        RestAssured.config = RestAssured.config().sslConfig(getConfiguredSslConfig());
        TicketRequest ticketRequest = new TicketRequest(APPLICATION_NAME);

        given()
            .contentType(JSON)
            .body(ticketRequest)
            .cookie(COOKIE, jwt)
        .when()
            .post(String.format("%s://%s:%d%s", SCHEME, HOST, PORT, TICKET_ENDPOINT))
        .then()
            .statusCode(is(SC_UNAUTHORIZED))
            .body("messages.find { it.messageNumber == 'ZWEAG130E' }.messageContent", equalTo(expectedMessage));
    }

    @Test
    public void doTicketWithInvalidHeader() {
        String jwt = "invalidToken";
        String expectedMessage = "Token is not valid for URL '" + TICKET_ENDPOINT + "'";

        RestAssured.config = RestAssured.config().sslConfig(getConfiguredSslConfig());
        TicketRequest ticketRequest = new TicketRequest(APPLICATION_NAME);

        given()
            .contentType(JSON)
            .body(ticketRequest)
            .header("Authorization", "Bearer " + jwt)
        .when()
            .post(String.format("%s://%s:%d%s", SCHEME, HOST, PORT, TICKET_ENDPOINT))
        .then()
            .statusCode(is(SC_UNAUTHORIZED))
            .body("messages.find { it.messageNumber == 'ZWEAG130E' }.messageContent", equalTo(expectedMessage));
    }

    @Test
    public void doTicketWithoutApplicationName() {
        String expectedMessage = "The 'applicationName' parameter name is missing.";

        RestAssured.config = RestAssured.config().sslConfig(getConfiguredSslConfig());
        String jwt = gatewayToken();

        given()
            .cookie(COOKIE, jwt)
        .when()
            .post(String.format("%s://%s:%d%s", SCHEME, HOST, PORT, TICKET_ENDPOINT))
        .then()
            .statusCode(is(SC_BAD_REQUEST))
            .body("messages.find { it.messageNumber == 'ZWEAG140E' }.messageContent", equalTo(expectedMessage));
    }

}
