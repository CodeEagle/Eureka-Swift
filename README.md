# nit-eureka-cli-swift-kit

# Eureka 服务

 json https://automationrhapsody.com/json-format-register-service-eureka/

 [xml](https://github.com/Netflix/eureka/wiki/Eureka-REST-operations)


 ```xml
 <application>
     <name>NIT-NODE-LF01</name>
     <instance>
       <instanceId>NIT-NODE-LF01:10.130.69.150:8602</instanceId>
       <hostName>10.130.69.150</hostName>
       <app>NIT-NODE-LF01</app>
       <ipAddr>10.130.69.150</ipAddr>
       <status>UP</status>
       <overriddenstatus>UNKNOWN</overriddenstatus>
       <port enabled="true">8602</port>
       <securePort enabled="false">7002</securePort>
       <countryId>1</countryId>
       <dataCenterInfo class="com.netflix.appinfo.InstanceInfo$DefaultDataCenterInfo">
         <name>MyOwn</name>
       </dataCenterInfo>
       <leaseInfo>
         <renewalIntervalInSecs>30</renewalIntervalInSecs>
         <durationInSecs>90</durationInSecs>
         <registrationTimestamp>1610502911723</registrationTimestamp>
         <lastRenewalTimestamp>1626338721406</lastRenewalTimestamp>
         <evictionTimestamp>0</evictionTimestamp>
         <serviceUpTimestamp>1610502911660</serviceUpTimestamp>
       </leaseInfo>
       <metadata class="java.util.Collections$EmptyMap"/>
       <homePageUrl>http://10.130.69.150:8602/</homePageUrl>
       <statusPageUrl>http://10.130.69.150:8602/public/info.html</statusPageUrl>
       <healthCheckUrl>http://10.130.69.150:8602/health</healthCheckUrl>
       <vipAddress>NIT-NODE-LF01</vipAddress>
       <isCoordinatingDiscoveryServer>false</isCoordinatingDiscoveryServer>
       <lastUpdatedTimestamp>1610502911723</lastUpdatedTimestamp>
       <lastDirtyTimestamp>1610502911722</lastDirtyTimestamp>
       <actionType>ADDED</actionType>
     </instance>
   </application>
 ```

