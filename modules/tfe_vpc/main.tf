# -----------------------------------------------------------------------------
# IP Allocation carving (assuming /16 CIDR) and other setup
# -----------------------------------------------------------------------------

locals {
  public_supernet  = cidrsubnet(var.cidr_block, 5, 0)
  private_supernet = cidrsubnet(var.cidr_block, 5, 1)
  db_supernet      = cidrsubnet(var.cidr_block, 5, 2)
}

# GET REGION WHERE WE ARE DEPLOYING
data "aws_region" "current" {}


# -----------------------------------------------------------------------------
# Virtual Private Cloud
# -----------------------------------------------------------------------------

# VPC
resource "aws_vpc" "main" {
  cidr_block                       = var.cidr_block
  assign_generated_ipv6_cidr_block = var.ipv6

  tags = merge({ Name = var.vpc_name }, var.tags)
}

# ADDITIONAL CIDRS, IF SPECIFIED
resource "aws_vpc_ipv4_cidr_block_association" "secondary_cidr" {
  for_each = toset(var.additional_cidrs)

  vpc_id     = aws_vpc.main.id
  cidr_block = each.key
}

# -----------------------------------------------------------------------------
# Internet Gateway
# -----------------------------------------------------------------------------

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge({ Name = "igw-${var.vpc_name}" }, var.tags)
}

# -----------------------------------------------------------------------------
# Public Subnets
# -----------------------------------------------------------------------------
locals {
  # Create a map of public subnets per AZ that can be interated over for subnet creation.
  public_subnets = { for az in var.azs : az => { cidr = cidrsubnet(local.public_supernet, 3, index(var.azs, az)) } }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = join("", [data.aws_region.current.name, each.key])
  map_public_ip_on_launch = true

  tags = merge({ Name = join("_", [var.vpc_name, "public", each.key]) }, var.tags)
}

# PUBLIC SUBNET ROUTE TABLE
resource "aws_route_table" "pub_rt" {
  vpc_id = aws_vpc.main.id

  tags = merge({ Name = join("_", [var.vpc_name, "publicRT"]) }, var.tags)
}

resource "aws_route" "pub_internet4" {
  route_table_id         = aws_route_table.pub_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route" "pub_internet6" {
  count = var.ipv6 ? 1 : 0

  route_table_id              = aws_route_table.pub_rt.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "pub_rt" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.pub_rt.id
}

# -----------------------------------------------------------------------------
# NAT Gateways
# -----------------------------------------------------------------------------

resource "aws_eip" "nat_gw" {
  for_each = local.public_subnets

  vpc = true
}

resource "aws_nat_gateway" "nat_gw" {
  for_each = local.public_subnets

  allocation_id = aws_eip.nat_gw[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge({ Name = join("_", [var.vpc_name, "natgw", each.key]) }, var.tags)
}

# -----------------------------------------------------------------------------
# Private Subnets
# -----------------------------------------------------------------------------
locals {
  # Create a map of private subnets per AZ that can be interated over for subnet creation.
  private_subnets = { for az in var.azs : az => { cidr = cidrsubnet(local.private_supernet, 3, index(var.azs, az)) } }
  db_subnets      = { for az in var.azs : az => { cidr = cidrsubnet(local.db_supernet, 3, index(var.azs, az)) } }
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = join("", [data.aws_region.current.name, each.key])

  tags = merge({ Name = join("_", [var.vpc_name, "private", each.key]) }, var.tags)
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = join("", [data.aws_region.current.name, each.key])

  tags = merge({ Name = join("_", [var.vpc_name, "private", each.key]) }, var.tags)
}


# PRIVATE SUBNET ROUTE TABLES
resource "aws_route_table" "priv_rt" {
  for_each = local.private_subnets

  vpc_id = aws_vpc.main.id

  tags = merge({ Name = join("_", [var.vpc_name, "privRT", each.key]) }, var.tags)
}

resource "aws_route" "priv_internet4" {
  for_each = local.private_subnets

  route_table_id         = aws_route_table.priv_rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw[each.key].id
}

resource "aws_route_table_association" "priv_rt" {
  for_each = local.private_subnets

  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.priv_rt[each.key].id
}

resource "aws_route_table_association" "db_rt" {
  for_each = local.db_subnets

  subnet_id      = aws_subnet.db[each.key].id
  route_table_id = aws_route_table.priv_rt[each.key].id
}
