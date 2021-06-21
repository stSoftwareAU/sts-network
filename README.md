# Pipeline to create the network layout

We create the private VPC "Main" and associated NAT gateways for each AZ in the created "Public" VPC.

There is no direct access from the internet to services in the "Main" VPC.

Following industry best practice "defence in depth", the CI/CD pipeline will be placed all DGA managed services in the "Main" VPC. 

We also create a private S3 bucket to store the terraform state for this and other pipelines.
