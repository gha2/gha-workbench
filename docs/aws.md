# AWS

This doc is a small memo on my current status about Spark/S3 on K8s POC on AWS

## Security model

### 'Raw' AWS

This part is not about K8S security model, which is clear and well known. 
What I would like to dicuss here is about allowing/securing access to AWS, non-K8S ressources, such as S3 buckets.

Rougly, there are two methods for an application to access a protected ressources on AWS:

- Provide an IAM user credential, referring to a user allowed to access the ressource (Either directly or by group membership). As we don't want to use an account referring to an physical person, this means creating IAM user as 'Technical account'

- Using the capability to associate a Role to an instance. This role may allow direct access to the target resources (By associating appropriate policies), or may be granted to switch to another role, which will host appropriate authorization. (Note there could be only one role bound to an instance)

The first method has the following drawback:
- Need to provide credentials to the application, typically in a secrets in a K8s context, who is, despite his name far to be 'secret'. And may end to store credential in Git.
- Or need to setup a vault. In addition to be complex, this is far from absolute, as credentials must be injected in the application, offering a way to a k8s admin to access them.
- Rotating the password is impractible, as there is no automated way to do so.
- And, last but not least, IAM account creation is not granted to us in the CAGIP lab context.

Anyway, the instance role is the recommended way to handle secure access on AWS. So, we will use this.

### In K8s

To view how this could works in a K8s context, one must first understand how it is implemented.

An AWS role is a credential managed by the system, and regulary rotated. When associated to an instance, such credential is included in the instance metadata. 

These metadatas are accessed using a specific URL: `http://169.254.169.254/latest/meta-data/` ([reference](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html)) The IP address 169.254.169.254 is a link-local address and is valid only from the instance. For more information, see Link-local address on Wikipedia.

In a K8s context, this means only POD bound to 'hostNetwork' will be able to access such metadata. Which is not the case for regular application PODs.

The solution then will be to proxify such metadata request. Fortunately, there is at least to [open sources projects performing this](https://www.kloia.com/blog/aws-resource-access-with-iam-role-from-kubernetes).

## Experimentation

### Current status

### Next step 

## Application deployment

## Links 

In the spark documentation: https://spark.apache.org/docs/latest/cloud-integration.html#authenticating

Some blogs about IAM and K8S relationship:

https://www.bluematador.com/blog/iam-access-in-kubernetes-the-aws-security-problem

https://medium.com/merapar/securing-iam-access-in-kubernetes-cfbcc6954de

https://www.kloia.com/blog/aws-resource-access-with-iam-role-from-kubernetes

