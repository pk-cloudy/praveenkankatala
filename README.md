API Gateway → Lambda Integration Tests – End-to-End Verification Document
1. Purpose

This document summarises all validation tests performed to verify how API Gateway accepts Lambda ARNs in the uri parameter of the Terraform resource:

resource "aws_api_gateway_integration" "lambda_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_invoke_arn
}


The goal is to clearly validate:

Which URI format works.

Why some formats fail.

What Terraform expects vs what AWS CLI/API returns.

The correct pattern for stable API Gateway → Lambda integrations.

2. Background

API Gateway expects a very specific URI format for Lambda proxy integrations:

Correct API Gateway URI pattern
arn:aws:apigateway:{region}:lambda:path/2015-03-31/functions/{lambda_function_arn}/invocations


Example:

arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:577064425470:function:my-function/invocations


Terraform’s lambda_invoke_arn output DOES NOT include this wrapper.
It only contains:

arn:aws:lambda:us-east-1:<account>:function:<function-name>:<alias>

3. Test Scenarios & Results
Test 1 — Manually Created API Gateway Integration
Terraform Not Used — Pure Console/CLI Integration

Command

aws apigateway get-integration \
  --rest-api-id cd4zic1nf5 \
  --resource-id 3qbrcw \
  --http-method POST \
  --query uri \
  --output text

Output
arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/
arn:aws:lambda:us-east-1:577064425470:function:test/invocations

Conclusion

✔ API Gateway automatically wraps the Lambda ARN inside the required apigateway: wrapper.
✔ Confirms the correct format.

Test 2 — Hard-coding the entire URI in Terraform
Terraform
uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:577064425470:function:my-private-lambda/invocations"

CLI Output
arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/
arn:aws:lambda:us-east-1:577064425470:function:my-private-lambda/invocations

Conclusion

✔ Works perfectly
✔ Terraform accepts this because the entire format is manually correct.
✔ API Gateway does not modify the URI if already correct.

Test 3 — Constructing URI using module-provided lambda_invoke_arn
Terraform
uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_invoke_arn}/invocations"

Terraform Error
BadRequestException: Invalid function ARN or invalid uri

Reason

var.lambda_invoke_arn already includes:

...:function:my-private-lambda:live


or

...:function:my-private-lambda


This introduces double wrapping or wrong formatting.

Example of what Terraform ends up outputting:

arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/
arn:aws:lambda:us-east-1:xxx:function:my-private-lambda:live/invocations


API Gateway does not accept invoke ARN with alias, nor duplicate ARN constructs.

Conclusion

❌ Fails
❌ Cannot build the wrapper URI using module output directly
❌ API Gateway rejects incorrect or alias-inflected ARNs

Test 4 — Passing Lambda Invoke ARN directly without wrapper
Terraform
lambda_invoke_arn = module.lambda_with_logs.lambda_invoke_arn

uri = var.lambda_invoke_arn

CLI Output
arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/
arn:aws:lambda:us-east-1:577064425470:function:my-private-lambda/invocations

Why does this work?

Terraform detects the resource type = AWS_PROXY and automatically builds the correct API Gateway wrapper when the supplied ARN is a plain Lambda invoke ARN.

So Terraform converts:

arn:aws:lambda:us-east-1:...:function:myprivateLambda


into:

arn:aws:apigateway:...:lambda:path/2015-03-31/functions/{lambdaArn}/invocations

Conclusion

✔ Works
✔ Simplest method
✔ Recommended method for AWS_PROXY integration
✔ Avoids manual URI construction mistakes

4. Summary Comparison Table
Test	Input (URI in Terraform)	Result	Notes
1	Manual API Setup	✔ Works	API creates correct wrapper
2	Full static URI	✔ Works	Only works if fully correct format
3	Wrapper + ${lambda_invoke_arn}	❌ Fails	Produced invalid URI
4	Passing lambda_invoke_arn directly	✔ Works	Terraform auto-wraps ARN
5. Final Recommended Implementation
Terraform — Correct & Recommended
uri = module.lambda_with_logs.lambda_invoke_arn


Terraform will automatically convert it into:

arn:aws:apigateway:<region>:lambda:path/2015-03-31/functions/<lambda_function_arn>/invocations

Why recommended

No formatting errors

No alias/suffix mistakes

Terraform automatically updates on Lambda ARN changes

Works with AWS_PROXY reliably

6. Key Technical Conclusions
✅ API Gateway requires the 2015-03-31 invoke path

This is fixed and does not change. It is the API version for Lambda integration.

❌ You cannot concatenate Terraform's lambda_invoke_arn into the wrapper URI

API Gateway rejects malformed ARNs.

✅ Terraform automatically builds the correct URI if you pass the raw invoke ARN

This is the safest and cleanest approach.

7. Final Recommendation

Use:

uri = module.lambda_with_logs.lambda_invoke_arn


Do NOT manually construct the apigateway: ARN unless necessary.
