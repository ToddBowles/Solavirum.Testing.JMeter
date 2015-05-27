package com.jmeter.custom.functions;

import org.junit.Assert;
import org.junit.Test;

import static org.junit.Assert.*;

public class AuthorizationHeaderTest {

    @Test
    public void LiveAgentApiAuthorizationHeaderTest_GenerateHeaderValue()
            throws Exception
    {
        String expectedHeaderValue = "ASDrRlk08F4ZEnZG5gE1UcJE/xG0nxbAsw7mu2rqz2J6MsmvNoqP0Zp8UJcJ3vSQq7G0kMUQgP/mSiLIpKbrohcVcMxjrk8w1aUmmm2ldXxejwPbLr5/fUDLgmDTo/jqEdGMwujRIT1HpB34qdkB05ARIYNENzDl4jeWv18OxVQ5akv3yRO3z+Td7e7pRqIwUUHn2cXiXoU71p1eAUvL883Cvhb4l61T0njPqAPpRss=";

        AuthorizationHeader header = new AuthorizationHeader("1", "ServerName", "DatabaseName");
        header.OverrideAuthorizationHeaderTimestamp = "2015-03-19T03:46:28.4614551Z";

        String actualHeaderValue = header.GenerateHeaderValue();

        Assert.assertEquals(expectedHeaderValue, actualHeaderValue);
    }

    @Test
    public void LiveAgentApiAuthorizationHeaderTest_InterpretHeaderValue()
            throws Exception
    {
        String header = "ASDrRlk08F4ZEnZG5gE1UcJE/xG0nxbAsw7mu2rqz2J6MsmvNoqP0Zp8UJcJ3vSQq7G0kMUQgP/mSiLIpKbrohcVcMxjrk8w1aUmmm2ldXxejwPbLr5/fUDLgmDTo/jqEdGMwujRIT1HpB34qdkB05ARIYNENzDl4jeWv18OxVQ5akv3yRO3z+Td7e7pRqIwUUHn2cXiXoU71p1eAUvL883Cvhb4l61T0njPqAPpRss=";

        String interpreted = AuthorizationHeader.InterpretHeaderValue(header);

        Assert.assertTrue(interpreted.contains("GatewayLive_01"));
    }
}