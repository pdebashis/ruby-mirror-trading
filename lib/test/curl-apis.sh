#REQUEST TOKEN

curl --location 'https://Openapi.5paisa.com/VendorsAPI/Service1.svc/TOTPLogin' \
--header 'Content-Type: application/json' \
--data '{
    "head": {
        "Key": "Sn4jWZkqB61kIvFogzDEfzfQ3JsRa18i"
    },
    "body": {
        "Email_ID": "REDACTED",
        "TOTP": "246983",
        "PIN": "REDACTED"
    }
}'

#{"body":{"ClientCode":"53570093","Message":"Success","RedirectURL":"","RequestToken":"REDACTED","Status":0,"Userkey":"Sn4jWZkqB61kIvFogzDEfzfQ3JsRa18i"},"head":{"Status":0,"StatusDescription":null}}



#ACCESS TOKEN

curl --location 'https://Openapi.5paisa.com/VendorsAPI/Service1.svc/GetAccessToken' \
--header 'Content-Type: application/json' \
--data '{
    "head": {
        "Key": "Sn4jWZkqB61kIvFogzDEfzfQ3JsRa18i"
    },
    "body": {
        "RequestToken": "REDACTED",
        "EncryKey": "yyQe3vgHypOUdGeF7o4v6jWuLIoGHSJ7",
        "UserId": "REDACTED"
    }
}'

#{"body":{"AccessToken":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1bmlxdWVfbmFtZSI6IjUzNTcwMDkzIiwicm9sZSI6IjE3NzIyIiwiU3RhdGUiOiIiLCJSZWRpcmVjdFNlcnZlciI6IkMiLCJuYmYiOjE2ODkwMDIxMjcsImV4cCI6MTY4OTAxMzc5OSwiaWF0IjoxNjg5MDAyMTI3fQ.rjEXTgDr04ZUuRGkQT0OH5skE4H7qdgP5gLl-6pCwD8","AllowBseCash":"Y","AllowBseDeriv":"N","AllowBseMF":"Y","AllowMCXComm":"Y","AllowMcxSx":"N","AllowNSECurrency":"Y","AllowNSEL":"Y","AllowNseCash":"Y","AllowNseComm":"N","AllowNseDeriv":"Y","AllowNseMF":"N","BulkOrderAllowed":0,"CleareDt":"\/Date(1688959800000+0530)\/","ClientCode":"53570093","ClientName":"SAGAR","ClientType":"1","CommodityEnabled":"Y","CustomerType":"OPTIMUM","DPInfoAvailable":"Y","DemoTrial":"N","DirectMFCharges":0,"IsIDBound":0,"IsIDBound2":0,"IsOnlyMF":"N","IsPLM":0,"IsPLMDefined":0,"Message":"Success","OTPCredentialID":"","PGCharges":10,"PLMsAllowed":0,"POAStatus":"N","PasswordChangeFlag":0,"PasswordChangeMessage":"","ReferralBenefits":0,"RefreshToken":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1bmlxdWVfbmFtZSI6IjUzNTcwMDkzIiwicm9sZSI6IjE3NzIyIiwiU3RhdGUiOiIiLCJSZWRpcmVjdFNlcnZlciI6IkMiLCJuYmYiOjE2ODkwMDIxMjcsImV4cCI6MTY5NjcwMzQwMCwiaWF0IjoxNjg5MDAyMTI3fQ.Pc94XFKLqmFLRSYOjerYi-_RssJx3oRnHT7EuMhd0L4","RunningAuthorization":0,"Status":0,"VersionChanged":0},"head":{"Status":0,"StatusDescription":"Success"}}

#MARGIN

curl --location --request POST 'https://Openapi.5paisa.com/VendorsAPI/Service1.svc/V4/Margin' \
--header 'Authorization: bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1bmlxdWVfbmFtZSI6IjUzNTcwMDkzIiwicm9sZSI6IjE3NzIyIiwiU3RhdGUiOiIiLCJSZWRpcmVjdFNlcnZlciI6IkMiLCJuYmYiOjE2ODkwMDYxNzMsImV4cCI6MTY4OTAxMzc5OSwiaWF0IjoxNjg5MDA2MTczfQ.1Xw15CgfDjOMeDB8FFhG0u2WlF6Y9pC1gYjI_XsuSFM' \
--header 'Content-Type: application/json' \
--header 'Cookie: NSC_JOh0em50e1pajl5b5jvyafempnkehc3=ffffffffaf103e0c45525d5f4f58455e445a4a423660' \
--data-raw '{
    "head": {
        "key": "Sn4jWZkqB61kIvFogzDEfzfQ3JsRa18i"
    },
    "body": {
        "ClientCode": "REDACTED"
    }
}'


#{"body":{"ClientCode":"REDACTED","EquityMargin":[{"AdhocMargin":0,"CollateralValueAfterHairCut":0,"DPFreeStockValue":44.83,"DerivativeMargin":0,"FundsPayln":473000,"FundsWithdrawal":0,"GrossHoldingValue":0,"GrossHoldingValueCoverPercentage":0,"HairCut":0,"Ledgerbalance":1235.91,"MFCollateralValueAfterHaircut":0,"MarginBlockedForPendingOrders":0,"MarginBlockedforOpenPostion_Cash":0,"MarginBlockedforOpenPostion_Collateral":0,"MarginBlockedforPendingOrder_Cash":0,"MarginBlockedforPendingOrder_Collateral":0,"MarginUtilized":0,"NetAvailableMargin":474235.91,"OptionsPremium":0,"TodaysLoss":0,"TotalCollateralValue":0,"Unsettled_Credits":0}],"MFMargin":[{"MFCollateralValue":0,"MFFreeStockValue":0,"MFHaircutValue":0}],"Message":"","Status":0,"TimeStamp":"\/Date(1688830922042+0530)\/"},"head":{"responseCode":"5PMarginV4","status":"0","statusDescription":"Success"}}

curl --location --request POST 'https://openapi.5paisa.com/VendorsAPI/Service1.svc/V1/PlaceOrderRequest' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer REDACTED' \
--header 'Cookie: 5paisacookie=j2usr4wuddgegs14hcjrh3d4; NSC_JOh0em50e1pajl5b5jvyafempnkehc3=ffffffffaf103e0f45525d5f4f58455e445a4a423660' \
--data-raw '{
    "head": {
        "key": "Sn4jWZkqB61kIvFogzDEfzfQ3JsRa18i"
    },
    "body": {
    "ClientCode":"REDACTED",
	"Exchange":"N",
	"ExchangeType" : "D",
    "Qty": "50",
    "Price": "0",
    "OrderType":"Buy",
	"ScripData" : "BANKNIFTY 13 Jul 2023 CE 45100.00_20230713_CE_45100",
	"IsIntraday" : true,
    "StopLossPrice":0,
    "IsAHOrder": "N",
	"AppSource" : "17722"
    }
}'


#{"body":{"BrokerOrderID":914643592,"ClientCode":"53570093","Exch":"N","ExchOrderID":"0","ExchType":"D","LocalOrderID":0,"Message":"Exchange is closed. Cannot place your order.","RMSResponseCode":-47,"RemoteOrderID":"{Your custom order tag}","ScripCode":41734,"Status":1,"Time":"\/Date(1688754600000+0530)\/"},"head":{"responseCode":"5PPlaceOrdReqV1","status":"0","statusDescription":"Success"}}








