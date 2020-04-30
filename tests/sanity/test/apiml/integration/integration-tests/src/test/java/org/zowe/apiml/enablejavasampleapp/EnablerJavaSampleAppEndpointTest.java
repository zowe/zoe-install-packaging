/*
 * This program and the accompanying materials are made available under the terms of the
 * Eclipse Public License v2.0 which accompanies this distribution, and is available at
 * https://www.eclipse.org/legal/epl-v20.html
 *
 * SPDX-License-Identifier: EPL-2.0
 *
 * Copyright Contributors to the Zowe Project.
 */
package org.zowe.apiml.enablejavasampleapp;

import io.restassured.RestAssured;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.zowe.apiml.util.categories.AdditionalLocalTest;
import org.zowe.apiml.util.http.HttpRequestUtils;

import java.net.URI;

import static io.restassured.RestAssured.given;
import static org.apache.http.HttpStatus.SC_OK;
import static org.hamcrest.Matchers.is;

@AdditionalLocalTest
public class EnablerJavaSampleAppEndpointTest {
    private static final String UI_V1_PATH = "/ui/v1/enablerJavaSampleApp/";
    private static final String APP_INFO_PATH = "/api/v1/enablerJavaSampleApp/application/info/";
    private static final String APP_INFO_HEALTH = "/api/v1/enablerJavaSampleApp/application/health/";
    private static final String GREETING_PATH = "/api/v1/enablerJavaSampleApp/greeting";
    private static final String GREETING_WITH_NAME_PATH = "/api/v1/enablerJavaSampleApp/greeting/Petr";
    private static final String JSON_CONTENT_TYPE = "application/json";

    @BeforeAll
    public static void beforeClass() {
        RestAssured.useRelaxedHTTPSValidation();
    }

    @Test
    public void shouldGetUI() {
        URI uri = HttpRequestUtils.getUriFromGateway(UI_V1_PATH);

        given()
        .when()
            .get(uri)
        .then()
            .statusCode(is(SC_OK))
            .contentType(is("text/html;charset=UTF-8"));
    }

    @Test
    public void shouldGetApplicationInfo() {
        URI uri = HttpRequestUtils.getUriFromGateway(APP_INFO_PATH);

        given()
        .when()
            .get(uri)
        .then()
            .statusCode(is(SC_OK))
            .contentType(is(JSON_CONTENT_TYPE));
    }


    @Test
    public void shouldGetHealth() {
        URI uri = HttpRequestUtils.getUriFromGateway(APP_INFO_HEALTH);

        given()
        .when()
            .get(uri)
        .then()
            .statusCode(is(SC_OK))
            .contentType(is(JSON_CONTENT_TYPE))
            .body("status", is("UP"));
    }

    @Test
    public void shouldGetGreeting() {
        URI uri = HttpRequestUtils.getUriFromGateway(GREETING_PATH);

        given()
        .when()
            .get(uri)
        .then()
            .statusCode(is(SC_OK))
            .body("content", is("Hello, World!"));
    }

    @Test
    public void shouldGetGreetingWithName() {
        URI uri = HttpRequestUtils.getUriFromGateway(GREETING_WITH_NAME_PATH);

        given()
        .when()
            .get(uri)
        .then()
            .statusCode(is(SC_OK))
            .body("content", is("Hello, Petr!"));
    }
}
