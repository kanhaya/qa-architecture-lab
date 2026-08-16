package com.qa.tests.tests.regression;

import org.junit.platform.suite.api.IncludeTags;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;

@Suite
@SelectPackages("com.qa.tests.tests")
@IncludeTags({"smoke", "functional", "negative"})
public class RegressionSuite {
}
