Load testing for something. Doesnt matter what. Creates a package for the load test itself (based around a JMX file) and also allows you to farm out that work to AWS.

This repository includes the JRE and JMeter dependencies, mostly to make the deployment to an AWS machine easier. They are 60MB all told, which makes me uncomfortable, but ah well, can't win them all.

To start JMeter and edit the load tests run the src/jmeter/scripts/open-jmeter-gui-for-edit.ps1 script.

The run the load tests with no GUI run src/jmeter/scripts/execute-load-test-no-gui.ps1.

The be fancy and farm out the load tests to AWS EC2 instances, run scripts/jmeter/farm-out-tests-to-aws.ps1.

Results will appear in the /results directory (log files and test results).
