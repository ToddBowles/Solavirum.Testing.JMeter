package com.jmeter.custom.functions;

import javax.crypto.Cipher;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Base64;
import java.util.Date;
import java.util.TimeZone;

/**
 * Created by tbowles on 3/20/2015.
 */
public class AuthorizationHeader
{
    private static final String AUTH_HEADER_CONTENT_JSON = "{\"Who\":{\"Id\":{\"CustomerNumber\":@@CUSTOMER_NUMBER,\"Database\":{\"Server\":\"@@DATABASE_SERVER_NAME\",\"DatabaseName\":\"@@DATABASE_NAME\"}}},\"When\":\"@@DATE_IN_UTC\"}";

    private static final String AUTH_HEADER_SHARED_SECRET = "BI3AH38BY08H3n9u9739723b39839820J286yf8YBKJIJ3B09U2iuQ9287jnbz83";
    private final String _CustomerNumber;
    private final String _DatabaseServerName;
    private final String _DatabaseName;

    public AuthorizationHeader(String customerNumber, String databaseServerName, String databaseName)
    {
        _CustomerNumber = customerNumber;
        _DatabaseServerName = databaseServerName;
        _DatabaseName = databaseName;
    }

    public String OverrideAuthorizationHeaderTimestamp;

    public String GenerateHeaderValue()
    {
        String authHeaderJson = AUTH_HEADER_CONTENT_JSON.replace("@@DATE_IN_UTC", GetTimestampForAuthUTCTimeInISO8601());
        authHeaderJson = authHeaderJson.replace("@@CUSTOMER_NUMBER", _CustomerNumber);
        authHeaderJson = authHeaderJson.replace("@@DATABASE_SERVER_NAME", _DatabaseServerName);
        authHeaderJson = authHeaderJson.replace("@@DATABASE_NAME", _DatabaseName);

        try
        {
            Cipher c = GetHeaderSpecificAESCipher(true);

            byte[] encrypted = c.doFinal(authHeaderJson.getBytes());
            return new String(Base64.getEncoder().encode(encrypted));
        }
        catch (Exception ex)
        {
            ex.printStackTrace();
            return "FAILED_TO_CREATE_AUTH_HEADER";
        }
    }

    public static String InterpretHeaderValue(String header)
    {
        try
        {
            byte[] decoded = Base64.getDecoder().decode(header);

            Cipher c = GetHeaderSpecificAESCipher(false);

            byte[] decrypted = c.doFinal(decoded);
            return new String(decrypted);
        }
        catch (Exception ex)
        {
            ex.printStackTrace();
            return "AUTH_HEADER_INVALID";
        }
    }

    private static Cipher GetHeaderSpecificAESCipher(Boolean forEncryption)
            throws Exception
    {
        byte[] decodedSharedSecret = Base64.getDecoder().decode(AUTH_HEADER_SHARED_SECRET);
        byte[] key = Arrays.copyOfRange(decodedSharedSecret, 0, 32);
        byte[] iv = Arrays.copyOfRange(decodedSharedSecret, 32, 48);

        Cipher c = Cipher.getInstance("AES/CBC/PKCS5PADDING");
        SecretKeySpec k = new SecretKeySpec(key, "AES");
        c.init(forEncryption ? Cipher.ENCRYPT_MODE : Cipher.DECRYPT_MODE, k, new IvParameterSpec(iv));

        return c;
    }

    private String GetTimestampForAuthUTCTimeInISO8601()
    {
        if (OverrideAuthorizationHeaderTimestamp != null)
        {
            return OverrideAuthorizationHeaderTimestamp;
        }

        TimeZone tz = TimeZone.getTimeZone("UTC");
        DateFormat df = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm'Z'");
        df.setTimeZone(tz);
        return df.format(new Date());
    }
}
