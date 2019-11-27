# Istio + GKE + Apigee

Wordsmith is the demo project shown at DockerCon EU 2017, where Docker announced that support for Kubernetes was coming to the Docker platform.

The demo app runs across three containers:

- [db](db/Dockerfile) - a Postgres database which stores words

- [words](words/Dockerfile) - a Java REST API which serves words read from the database

- [words-v2](words-v2/Dockerfile) - a Java REST API which serves words + v2 read from the database, this version was instruduced for this example (istio) and doesn't exisist in the original repo

- [web](web/Dockerfile) - a Go web application which calls the API and builds words into sentences:

## For further references of this project please visit: [K8s Word Smith](https://github.com/dockersamples/k8s-wordsmith-demo)

# Must Have for this example

The Requirements for this example are:

```
GKE Cluster with Istio Enabled (At least 3 nodes n1-standard-2, mTLS Strict)

KubeControl (kubectl) on your Machine

Istio (istioctl) on your Machine

Docker on your machine
```

> You can use pre-built images from Docker Hub Described on [Deploy File](k8s-deploy/words-smith-deploy.yaml) or you can tag and push the images on your project private gcr.io (this apply for these Docker files: - [db](db/Dockerfile),[words](words/Dockerfile),[words-v2](words-v2/Dockerfile),[web](web/Dockerfile))
```
docker build -t gcr.io/your-gcp-project/words-v2:latest .
docker push gcr.io/your-gcp-project/words-v2:latest
```

## Deploy `Words` as K8S Stack
From root folder of project:
- Create NameSpaces for the Stack
```
$ chmod +d k8s-deployment/namespaces.sh
$ ./k8s-deployment/namespaces.sh
```
- Then verify namespaces:
```
$ kubectl get namespaces
NAME              STATUS   AGE
api               Active   150m
database          Active   150m
default           Active   152m
istio-system      Active   152m
web               Active   150m
```
- Now you can execute deployment with kubectl [Deploy](k8s-deploy/words-smith-deploy.yaml)
```
kubectl apply -f k8s-deploy/words-smith-deploy.yaml
```
Wait until finish, and verify with the following command, you'll also see all istio services:

```
$ kubectl get svc -A
NAME   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
db     ClusterIP   10.28.15.16   <none>        5432/TCP   137m
web    ClusterIP   10.28.0.76    <none>        8081/TCP   137m
words  ClusterIP   10.28.5.85    <none>        8080/TCP   137m
```
## Deploy Istio components
- Next you need to create an `Istio GateWay`  and `VirtualServices` to map the web app with the correct gateway with the following file [GateWayAndVirtualSVC](istio/gateway-words.yaml):
```
$ kubectl apply -f istio/gateway-words.yaml
```
- Validate the gateway and virtual service:
```
$ kubectl get Gateway -A
NAMESPACE      NAME             AGE
istio-system   ingressgateway   129m
web            web-gateway      161m
```
```
$ kubectl get VirtualService -A
NAMESPACE   NAME                   GATEWAYS        HOSTS     AGE
web         web-virtualservice     [web-gateway]   [*]       162m
```

- Now we need a virtual service and a destination rule to direct web trafic to words api to be able to get words 
- Execute the deployment with [VirtualServiceAndDestinationRoute](istio/route-words.yaml)
```
$ kubectl apply -f istio/route-words.yaml
```
- Verify virtual service and destination routes
```
$ kubectl get VirtualService -A
NAMESPACE   NAME                   GATEWAYS        HOSTS     AGE
api         words-virtualservice                   [words]   106m
web         web-virtualservice     [web-gateway]   [*]       162m
```
```
$ kubectl get DestinationRule -A
NAMESPACE      NAME                HOST                                             AGE
api            words-destination   words                                            166m
```
- Now you can verify the web app working on the `Istio ingress IP`
- How to locate [Istio Gateway](https://istio.io/docs/concepts/traffic-management/#gateways)
- You'll see something like this:![words](img/webbappwords.png)

## Deploy `Words` as Canary Deployment for words API
- Delete words virtual service
```
kubectl delete VirtualService words-virtualservice
```
- Execute the canary deployment with [Canary](istio/canary-words.yaml)
```
$ kubectl apply -f istio/canary-words.yaml
```
- To verify this execute 
```
$ kubectl get VirtualService -A
NAMESPACE   NAME                   GATEWAYS        HOSTS     AGE
api         words-virtualservice                   [words]   106m
web         web-virtualservice     [web-gateway]   [*]       162m
```
- In order to visualise this behaviour we need to instal [Kaili](https://istio.io/docs/tasks/observability/kiali/)
- After done Kaili installation, Login into Kaili -> Graph
- Select three namespaces: web, api, database
- Versioned app graph
- Requests percentage
- And you'll se something like:
![Kiali](img/kiali.png)

# Apigee
In order to enable Apigee with Istio, we need to replace Mixer from Istio with a Powered Mixer from Apigee
You'll need an [Apigee](https://apigee.com/) account, with the free version it's ok
- First we need to create a apigee isto adapter, please refer to [apigee docs](https://docs.apigee.com/api-platform/istio-adapter/install-istio_1_1#provision_components_on_edge_public_cloud)
- Once you get your handler like this:
```
# Istio handler configuration for Apigee gRPC adapter for Mixer
apiVersion: config.istio.io/v1alpha2
kind: handler
metadata:
  name: apigee-handler
  namespace: istio-system
spec:
  adapter: apigee
  connection:
    address: apigee-adapter:5000
  params:
    apigee_base: https://istioservices.apigee.net/edgemicro
    customer_base: https://myorg-env.apigee.net/istio-auth
    org_name: myorg
    env_name: myenv
    key: 06a40b65005d03ea24c0d53de69ab795590b0c332526e97fed549471bdea00b9
    secret: 93550179f344150c6474956994e0943b3e93a3c90c64035f378dc05c98389633 
```
- You must create the `Adapter and Configurations` for Apigee on your cluster 
```
$ kubectl apply -f apigee
deployment.extensions/apigee-adapter created
service/apigee-adapter created
instance.config.istio.io/apigee-authorization created
instance.config.istio.io/apigee-authorization-web created
instance.config.istio.io/apigee-analytics created
template.config.istio.io/apigee-authorization created
template.config.istio.io/apigee-analytics created
adapter.config.istio.io/apigee created
handler.config.istio.io/apigee-handler created
rule.config.istio.io/apigee-rule created
rule.config.istio.io/apigee-rule-web created
```
- You will be able to see an API Proxy on your [Apigee Edge page](https://apigee.com/edge)
![Apigee proxy](img/apigee-proxy.png)
- You will not able to see Words web app, the web was secured by apigee

![blocked by proxy](img/wordwebblocked.png)
- Register your Api Product, with the following configurations

![wordwebblocked.png](img/wordwebblocked.png)

- Create a new developer

![newdeveloper.png](img/newdeveloper.png)
- And now create a new app

![newdeveloper.png](img/newapp.png)

- With App credential Key, set as header on your call to web app, you'll be able to connect again to web app

![webcall.png](img/callwithheader.png)

- If you want to disableb apigee security on any namespace, you need to modify [apigee rule](apigee/rule.yaml), delete autorization-web line on instances
```
apiVersion: config.istio.io/v1alpha2
kind: rule
metadata:
  name: apigee-rule-web
  namespace: istio-system
spec:
  match: context.reporter.kind == "inbound" && destination.namespace == "web"
  actions:
  - handler: apigee-handler
    instances:
    - apigee-analytics
```