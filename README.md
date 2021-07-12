# Secure Network Architecture Model
![Alt text](https://lucid.app/publicSegments/view/59ab75ca-07e4-4ebf-80dc-3cbe4cbaad31/image.png "Network Diagram ^1")

## The Terraform IaC (Infrastructure a Code) script creates 
1. A VPC (  Virtual Private Cloud ) "Main"
2. A "public" and "private" subnet for each availability zone ( three ).
3. For in each "public" subnet, a NAT Gateway 
4. For each "private" subnet, a routeing table to the associated NAT Gateway in the corresponding "public" subnet. 
5. For each "private" subnet, an [AWS Endpoint](https://docs.aws.amazon.com/vpc/latest/privatelink/endpoint-service.html) for the AWS services S3, SSM, EC2 Messages and SSM Messages. Which will allow direct access to these services from the "private" subnet without going through the "public" NAT gateway. Using endpoints for these AWS services, we do not send sensitive data via the public Internet and reduce data transmission costs.
6. We create a private S3 bucket to store all the logs, encrypted, versioned, and lifecycle to transition to glazer storage and eventual expiry.
7. We create Roles and security groups for [SSM](https://docs.aws.amazon.com/systems-manager/latest/userguide/create-ssm-doc.html).
8. An internet gateway
9. A Elastic IP for each NAT Gateway, which will mean all "private" sevices will have a known and static set of IPs.


All AWS accounts that host services ( all but the user identity AWS account) will use this network model. 

For each availability zone, there will be a "public" and "private" subnet. Data.gov.au (DGA) will place all Self-managed services in a "private" subnet; only AWS managed services ( Load Balancer, NAT Gateway etc.) will be placed in a "public" subnet.

## [Subnet types.](https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.SubnetType.html)
Name | Description
-----|------------
PRIVATE  | Subnet that routes to the Internet, but not vice versa.
PUBLIC   | Subnet connected to the Internet.

## Service Access
To access services within a "private" subnet, we will use [AWS Systems Manager](https://docs.aws.amazon.com/systems-manager/latest/userguide/create-ssm-doc.html).

[^1]:[__Diagram Source__](https://lucid.app/lucidchart/invitations/accept/inv_217a3583-7d0e-45f3-b890-a897228feff0?viewport_loc=-387%2C-77%2C1664%2C870%2C2w9TLrWH43pa)
