package com.jmeter.custom.functions;

import java.security.NoSuchAlgorithmException;
import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.*;

import org.apache.jmeter.engine.util.CompoundVariable;
import org.apache.jmeter.functions.AbstractFunction;
import org.apache.jmeter.functions.InvalidVariableException;
import org.apache.jmeter.samplers.SampleResult;
import org.apache.jmeter.samplers.Sampler;

import javax.crypto.Cipher;
import javax.crypto.NoSuchPaddingException;
import javax.crypto.spec.IvParameterSpec;
import javax.crypto.spec.SecretKeySpec;

public class AuthorizationHeaderJMeterFunction extends AbstractFunction {

    private static final List<String> desc = new LinkedList<String>();
    private static final String KEY = "__CreateAuthorizationHeader";
    private static final int MAX_PARAM_COUNT = 3;
    private static final int MIN_PARAM_COUNT = 3;

    private CompoundVariable[] _Parameters;

    static {
        desc.add("Customer Number");
        desc.add("Database Server Name");
        desc.add("Database Name");
    }

    /**
     * No-arg constructor.
     */
    public AuthorizationHeaderJMeterFunction() {
        super();
    }

    /** {@inheritDoc} */
    @Override
    public synchronized String execute(SampleResult previousResult, Sampler currentSampler)
            throws InvalidVariableException
    {
        AuthorizationHeader header = new AuthorizationHeader(_Parameters[0].execute(), _Parameters[1].execute(), _Parameters[2].execute());
        return header.GenerateHeaderValue();
    }

    /** {@inheritDoc} */
    @Override
    public synchronized void setParameters(Collection<CompoundVariable> parameters)
            throws InvalidVariableException
    {
        checkParameterCount(parameters, MIN_PARAM_COUNT, MAX_PARAM_COUNT);
        _Parameters = new CompoundVariable[parameters.size()];
        _Parameters = parameters.toArray(_Parameters);
    }

    /** {@inheritDoc} */
    @Override
    public String getReferenceKey() {
        return KEY;
    }

    /** {@inheritDoc} */
    @Override
    public List<String> getArgumentDesc() {
        return desc;
    }
}

