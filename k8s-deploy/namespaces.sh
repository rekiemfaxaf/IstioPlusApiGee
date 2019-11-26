kubectl create namespace api 
kubectl create namespace database
kubectl create namespace web 
kubectl label namespace default istio-injection=enabled
kubectl label namespace web istio-injection=enabled
kubectl label namespace api istio-injection=enabled
kubectl label namespace database istio-injection=enabled