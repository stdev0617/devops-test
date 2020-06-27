# spring-petclinic-data-jdbc for kubernetes

### 전제조건

- 본 프로젝트는 아래의 내용을 가정한다.

1. kubernetes 버전 1.15 version 이하 (1.16이상부터 apiVersion 문제로 yaml 설정이 다르기때문)버전의 kubernetes가 설치되어있다고 가정한다.

2. mysql과 petclinic application이 연결되어있다고 가정한다.

   (현재 mysql과 petclinic는 각각 pod로 띄울 수 있지만 Communications link failure 문제가 있어서 연결작업은 진행하지 못했다.)

3. mysql root의 비밀번호는 admin이라고 가정한다(secret에 password를 encode해서 적용시켜두었다.)



### 실행방법

1. petclinic gradle build 및 docker image build

   ```
   ./gradlew build
   docker build --tag stdev0617/petclinic:latest .
   ```

2. deploy

   1) mysql 배포
   ```
   kubectl create -f ./kubernetes/mysql/mysql-pv.yaml

   kubectl create -f ./kubernetes/mysql/mysql-pvc.yaml

   kubectl create -f ./kubernetes/mysql/mysql-secret.yaml

   kubectl create -f ./kubernetes/mysql/mysql-service.yaml

   kubectl create -f ./kubernetes/mysql/mysql-statefulset.yaml
   ```
   

   2) petclinic 배포
   ```
   kubectl create -f ./kubernetes/petClinic/petclinic-service.yaml

   kubectl create -f ./kubernetes/petClinic/petclinic-ingress.yaml

   kubectl create -f ./kubernetes/petClinic/petclinic-deployment.yaml
   ```


### 해결방법

1. gradle을 사용하여 어플리케이션과 도커이미지를 빌드한다. (실행방법 참고)

   - maven -> gradle 변환

   - docker buil 명령어 사용

2. 어플리케이션의 log는 host의 /logs 디렉토리에 적재되도록 한다.

   - petClinic의 application.properties에 아래 설정 추가

     `logging.file.path=/logs`

3. 정상 동작 여부를 반환하는 api를 구현하며, 10초에 한번 체크하도록 한다. 3번 연속 체크에 실패하면 어플리케이션은 restart 된다. 
   - springBoot의 actuator 기능과 kubernetes의 liveness를 사용해서 해결하려고 했으나 db연결이 안되어 확인하지 못함.

4. 종료 시 30초 이내에 프로세스가 종료되지 않으면 SIGKILL로 강제 종료 시킨다.

   - petclinic-deployment.yaml의 template 설정에 `terminationGracePeriodSeconds: 30` 추가

5. 배포 시와 scale in/out 시 유실되는 트래픽이 없어야 한다.
   - 배포전략으로 rollingupdate 전략 사용
      ```
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0
      type: RollingUpdate
     ```

6. 어플리케이션 프로세스는 root 계정이 아닌 uid:1000으로 실행한다

   - petclinic-deployment.yaml의 template 설정에 아래 내용 추가
   ```
         securityContext:
           runAsUser: 1000
   ```
7. DB도 kubernetes에서 실행하며 재 실행 시에도 변경된 데이터는 유실되지 않도록 설정한다. 어플리케이션과 DB는 cluster domain을 이용하여 통신한다.

   - db 데이터 유실을 막기위해 PersistentVolume사용

   - cluster domain 통신을 위해 petclinic-deployment에 아래의 container env 추가
   ```
              env:
                 - name: SPRING_DATASOURCE_URL
                   value: jdbc:mysql://mysql-service.default.svc.cluster.local/petclinic
   ```
8. nginx-ingress-controller를 통해 어플리케이션에 접속이 가능하다.

   petclinic-ingress.yaml 참고
