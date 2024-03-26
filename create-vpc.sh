
#!/bin/bash

# Note: Configure the aws credentials in the terminal before running the script 

# Create a VPC
vpc_id=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=my-shell-vpc}]' --query Vpc.VpcId --output text)
echo $vpc_id

# Create a public subnet in az us-east-1a
public_subnetId_1=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.0.0/18 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pub-subnet-1}]' --availability-zone us-east-1a --query Subnet.SubnetId --output text)
echo $public_subnetId_1

# Create a public subnet in az us-east-1b
public_subnetId_2=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.64.0/18 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pub-subnet-2}]' --availability-zone us-east-1b --query Subnet.SubnetId --output text)
echo $public_subnetId_2

# Create a private subnet in az us-east-1a
private_subnetId_1=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.128.0/18 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pri-subnet-1}]' --availability-zone us-east-1a --query Subnet.SubnetId --output text)
echo $private_subnetId_1

# Create a private subnet in az us-east-1b
private_subnetId_2=$(aws ec2 create-subnet --vpc-id $vpc_id --cidr-block 10.0.192.0/18 --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=pri-subnet-2}]' --availability-zone us-east-1b --query Subnet.SubnetId --output text)
echo $private_subnetId_2

# Create an Internet Gateway
int_gwy_id=$(aws ec2 create-internet-gateway --tag-specifications 'ResourceType=internet-gateway,Tags=[{Key=Name,Value=internet-gwy}]' --query InternetGateway.InternetGatewayId --output text)
echo $int_gwy_id

# Attach the above created internet gateway to the VPC
aws ec2 attach-internet-gateway --vpc-id $vpc_id --internet-gateway-id $int_gwy_id

# Create a route table for the public subnets
pub_route_tbl_id=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=public-aws-route-table}]' --query RouteTable.RouteTableId --output text)

# Create a route table for 1st private subnet
private_route_tbl_id1=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-aws-route-table-1}]' --query RouteTable.RouteTableId --output text)

# Create a route table for 2nd private subnet
private_route_tbl_id2=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications 'ResourceType=route-table,Tags=[{Key=Name,Value=private-aws-route-table-2}]' --query RouteTable.RouteTableId --output text)

# Create a route in the route table that sends all IPv4 traffic to the internet gateway
aws ec2 create-route --route-table-id $pub_route_tbl_id --destination-cidr-block 0.0.0.0/0 --gateway-id $int_gwy_id

# Associate the route table with the public subnets 1 and 2
aws ec2 associate-route-table --route-table-id $pub_route_tbl_id --subnet-id $public_subnetId_1
aws ec2 associate-route-table --route-table-id $pub_route_tbl_id --subnet-id $public_subnetId_2

# Associate the route table with the private subnet 1
aws ec2 associate-route-table --route-table-id $private_route_tbl_id1 --subnet-id $private_subnetId_1

# Associate the other route table with the private subnet 2
aws ec2 associate-route-table --route-table-id $private_route_tbl_id2 --subnet-id $private_subnetId_2

# Create an elastic IP address for the NAT gateway
eipalloc_id=$(aws ec2 allocate-address --domain vpc --tag-specifications 'ResourceType=elastic-ip,Tags=[{Key=Name,Value=Eip-allacation-id}]' --query AllocationId --output text)
echo $eipalloc_id

# Create the NAT gateway
nat_id=$(aws ec2 create-nat-gateway --subnet-id $public_subnetId_1 --allocation-id $eipalloc_id --tag-specifications 'ResourceType=natgateway,Tags=[{Key=Name,Value=Nat-Gateway}]' --query NatGateway.NatGatewayId --output text)
echo $nat_id

sleep 90

# Create a route in the route table for the private subnet 1 and 2 that sends all IPv4 traffic to the NAT gateway
aws ec2 create-route --route-table-id $private_route_tbl_id1 --destination-cidr-block 0.0.0.0/0 --gateway-id $nat_id
aws ec2 create-route --route-table-id $private_route_tbl_id2 --destination-cidr-block 0.0.0.0/0 --gateway-id $nat_id

# Create a gateway S3 endpoint
aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.us-east-1.s3 --route-table-ids $private_route_tbl_id1 --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=S3-endpoint}]'

# Create a gateway DynamoDB endpoint
aws ec2 create-vpc-endpoint --vpc-id $vpc_id --service-name com.amazonaws.us-east-1.dynamodb --route-table-ids $private_route_tbl_id2 --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Name,Value=DynamoDB-endpoint}]'
