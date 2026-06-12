/*
 *  Copyright (c) 2026, WSO2 LLC. (http://www.wso2.org) All Rights Reserved.
 *
 *  WSO2 LLC. licenses this file to you under the Apache License,
 *  Version 2.0 (the "License"); you may not use this file except
 *  in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

package io.ballerina.edi.cmd;

import com.google.gson.JsonElement;
import com.google.gson.JsonParser;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Shared helpers for the CLI command tests.
 */
final class TestUtils {

    private TestUtils() {
    }

    /**
     * Root of the shared test data in edi-tools/tests/resources, passed in by the Gradle test task.
     */
    static Path testResources() {
        return Paths.get(System.getProperty("edi.tools.test.resources"));
    }

    /**
     * Copies a classpath test resource into the given directory and returns its path.
     */
    static Path copyResource(String resourceName, Path targetDir) throws IOException {
        Path target = targetDir.resolve(Paths.get(resourceName).getFileName().toString());
        try (InputStream in = TestUtils.class.getClassLoader().getResourceAsStream(resourceName)) {
            Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
        }
        return target;
    }

    /**
     * Asserts that two JSON files hold semantically equal content.
     */
    static void assertJsonEquals(Path expected, Path actual) throws IOException {
        assertTrue(Files.exists(actual), "Expected output file was not generated: " + actual);
        JsonElement expectedJson = JsonParser.parseString(Files.readString(expected));
        JsonElement actualJson = JsonParser.parseString(Files.readString(actual));
        assertEquals(expectedJson, actualJson, "Generated schema does not match " + expected);
    }
}
