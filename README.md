Load testing for the LiveAgentService.

This repository includes the JRE and JMeter dependencies, mostly to make the deployment to an AWS machine easier. They are 60MB all told, which makes me uncomfortable, but ah well, can't win them all.

To start JMeter and edit the load tests run the scripts/jmeter/open-jmeter-gui-for-edit.ps1 script.

The run the load tests with no GUI run scripts/jmeter/execute-load-test-no-gui.ps1.

Results will appear in the /results directory (log files and test results).