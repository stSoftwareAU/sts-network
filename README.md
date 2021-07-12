# Generic Secure Network Architecture

All AWS accounts that host services ( all but the user identity AWS account) will use this generic network layout. 

For each availability zone, there will be a "public" and "private" subnet. DGA will place all Self-managed services in a "private" subnet; only AWS managed services ( Load Balancer, NAT Gateway etc.) will be placed in a "public" subnet.

## [Subnet types.](https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.SubnetType.html)
Name | Description
-----|------------
ISOLATED | Isolated Subnets do not route traffic to the Internet (in this VPC).
PRIVATE  | Subnet that routes to the Internet, but not vice versa.
PUBLIC   | Subnet connected to the Internet.

## Service Access
To access services within a "private" subnet, we will use [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/create-ssm-doc.html) instead of a bastion host or other solution.

## Resources created
The Terraform IaC (Infrastructure a Code) script creates 
* A VPC (  Virtual Private Cloud ) "Main"
* A "public" and "private" subnet for each availability zone ( three ).
* For in each "public" subnet, a NAT Gateway 
* For each "private" subnet, a routeing table to the associated NAT Gateway in the corresponding "public" subnet. 
* For each "private" subnet, an [AWS Endpoint](https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-service.html) for the AWS services S3, SSM, EC2 Messages and SSM Messages. Which will allow direct access to these services from the "private" subnet without going through the "public" NAT gateway. Using endpoints for these AWS services, we do not send sensitive data via the public Internet and reduce data transmission costs.
* We create a private S3 bucket to store all the logs, encrypted, versioned, and lifecycle to transition to glazer storage and eventual expiry.
* We create Roles and security groups for [SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/create-ssm-doc.html).

## Diagram
![Alt text](/documentation/images/dga-network-pipeline.png?raw=true "Network Diagram")

https://lucid.app/lucidchart/invitations/accept/inv_217a3583-7d0e-45f3-b890-a897228feff0?viewport_loc=-387%2C-77%2C1664%2C870%2C2w9TLrWH43pa

