# AWS

This doc is a small memo on my current status about Spark/S3 on K8s POC on AWS

## Security model

This part is not about K8S security model, which is clear and well known.
What I would like to dicuss here is about allowing/securing access to AWS, non-K8S ressources, such as S3 buckets.

### 'Raw' AWS

Rougly, there are two methods for an application to access a protected ressources on AWS:

- Provide an IAM user credential, referring to a user allowed to access the ressource (Either directly or by group membership). As we don't want to use an account referring to an physical person, this means creating IAM user as 'Technical account'

- Using the capability to associate a Role to an instance. This role may allow direct access to the target resources (By associating appropriate policies), or may be granted to switch to another role, which will host appropriate authorization. (Note there could be only one role bound to an instance)

The first method has the following drawback:
- Need to provide credentials to the application, typically in a secrets in a K8s context, who is, despite his name far to be 'secret'. And may end to store credential in Git.
- Or need to setup a vault. In addition to be complex, this is far from absolute, as credentials must be injected in the application, offering a way to a k8s admin to access them.
- Rotating the password is impracticable, as there is no automated way to do so.
- And, last but not least, IAM account creation is not granted to us in the CAGIP lab context.

Anyway, the instance role is the recommended way to handle secure access on AWS. So, we will use this.

### In K8s

To view how this could work in a K8s context, one must first understand how it is implemented.

An AWS role is a credential managed by the system, and regulary rotated. When associated to an instance, such credential is accessible from the instance metadata. 

These metadatas are accessed using a specific URL: `http://169.254.169.254/latest/meta-data/` ([reference](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html)) The IP address 169.254.169.254 is a link-local address and is valid only from the instance. For more information, see Link-local address on Wikipedia.

In a K8s context, this means only POD bound to 'hostNetwork' will be able to access such metadata. This is not the case for regular application PODs.

The solution then will be to proxify such metadata request. Fortunately, there is at least two [open sources projects performing this](https://www.kloia.com/blog/aws-resource-access-with-iam-role-from-kubernetes). Also, these proxy will allow to implement some access control on the role which can be used, based on the namespace.

## Experimentation

To experiment this security model, we made first some test on a single instance (Named single1). 

For this, we created 3 roles, and associated policies:

- `single1_gha1`, which will allow access to all buckets where the name begin by `gha1-`
- `single1_gha2`, which will allow access to all buckets where the name begin by `gha2-`
- `single1_instance`, aimed to be bound to the instance. This role will allow switching to the two other just decribed. It will also allow access to all buckets where name start with `gha-`

We associate the role `single1_instance` to our test instance.

Then we create 3 buckets: `gha1-primary-1`, `gha2-primary1` and `gha-common-1`. And we create a folder with a file in each bucket, just to be able to list content.

All theses object was created using terraform. The manifest files can be found here: https://github.com/SergeAlexandre/go2s3/tree/master/terraform

### CLI based test

Then, once logged to our test instance:

- If not done already, install the aws cli (`sudo yum  install awscli`)
- DO NOT perform `aws configure`. We don't want to use an explicit credential.

Check we can only access to a bucket were the name begin by `gha-`:
```
$ aws s3 ls s3://gha-common-1
                           PRE gha_common_content/

$ aws s3 ls s3://gha1-primary-1

An error occurred (AccessDenied) when calling the ListObjects operation: Access Denied

$ aws s3 ls s3://gha2-primary-1

An error occurred (AccessDenied) when calling the ListObjects operation: Access Denied
```

To access the `gha1-primary-1` bucket, we must switch to the `single1_gha1` role. And to `single1_gha2` role to access `gha2-primary-1` bucket.

For the AWS CLI, this can be archived by defining some profiles in the `~/.aws/config` file:

```
[profile gha1]
role_arn = arn:aws:iam::<myAccountId>:role/single1_gha1
credential_source = Ec2InstanceMetadata

[profile gha2]
role_arn = arn:aws:iam::<myAccountId>:role/single1_gha2
credential_source = Ec2InstanceMetadata
```

Where `<myAccountId>` is your AWS account ID (12 numbers)

Then one can check using `gha1` profile that access is granted to `gha-primary-1`. But not to `gha2-primary-1` nor `gha-common-1`. (The attached role `single1_instance` has been fully superseded by the assumed one).

```
$ aws s3 ls --profile gha1 s3://gha1-primary-1
                           PRE gha1_primary1_content/

$ aws s3 ls --profile gha1 s3://gha2-primary-1

An error occurred (AccessDenied) when calling the ListObjects operation: Access Denied

$ aws s3 ls --profile gha1 s3://gha-common-1

An error occurred (AccessDenied) when calling the ListObjects operation: Access Denied
```

### API based test

Then, next step is to experiment this security model through an application.

For this, we will use a small python test program: https://github.com/SergeAlexandre/go2s3

See the associated README.md

Also, there is [`gha2s3`](https://github.com/gha2/gha2s3), which is a rewrite of `gha2minio`, using AWS boto3 API instead of minio SDK, and aimed to transfer github archive to minio or AWS S3

### Spark tests

The next step is to  experiment this security model using Spark running in client mode in a VM on AWS.

The Java spark application 'gha2spark' has been improved to handle assume role switching.

The key point on this is the [spark-defaults.conf](https://github.com/SergeAlexandre/go2s3/blob/master/spark/spark-3.1.1/conf/spark-defaults.conf) configuration file.

### Next step 

- Replace `gha2minio` by `gha2s3` in the current (non AWS) POC implementation.
- Update and validate new `gha2spark` in the current (non AWS) POC implementation.
- Make all this working in a Kubernetes context.
- Works on long running jobs, as session of assume role is granted for only one hour.

## Application deployment

Here are some thought about application deployment and corridor pattern.

A corridor is a set of ressource created by an administrator to allow an application manager to deploy. Such pattern should allow several corridors to coexist on the same infrastructure in a fully isolated way.

For the case of a simple Spark application on Kubernetes, a corridor is typically made of:
- A Kubernetes namespace to launch Spark inside
- A Kubernetes ServiceAccount
- One or several buckets. A naming convention will be useful here, by naming all buckets of a corridor by a prefix.
- AWS Roles and Policies allowing access to the target buckets.

So a corridor is made of both Kubernetes and AWS ressources. To have a purely descriptive deployment, a corridor can be defined by both Kubernetes and Terraform manifests.

And alternate approach would be to use some Kubernetes operator aimed to manage AWS ressources. This will allow to fully describe targets with only Kubernetes manifests, thus using tools such as ArgoCD.

## Links 

In the spark documentation: https://spark.apache.org/docs/latest/cloud-integration.html#authenticating

From databricks: https://docs.databricks.com/administration-guide/cloud-configurations/aws/assume-role.html

https://stackoverflow.com/questions/44316061/does-spark-allow-to-use-amazon-assumed-role-and-sts-temporary-credentials-for-dy

Some blogs about IAM and K8S relationship:

https://www.bluematador.com/blog/iam-access-in-kubernetes-the-aws-security-problem

https://medium.com/merapar/securing-iam-access-in-kubernetes-cfbcc6954de

https://www.kloia.com/blog/aws-resource-access-with-iam-role-from-kubernetes

