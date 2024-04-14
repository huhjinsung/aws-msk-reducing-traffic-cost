# aws-msk-reducing-traffic-cost

## 개요
이번 레포지터리에서는 AWS의 관리형 아파치 카프카 서비스인 Amazon MSK를 사용하면서 발생하는 트래픽 비용을 줄이는 전략에 대해서 소개합니다. AWS를 사용할 경우 가용영역(AZ)간 통신 시 트래픽 비용이 발생하며, Amazon MSK의 경우 여러 가용영역(2개 or 3개)에 걸쳐 브로커를 배치합니다. 만약 AZ-a에 위치한 Consumer가 AZ-c에 위치한 MSK 브로커에서 데이터를 읽을 경우 AZ간 트래픽이 발생하며 이로 인한 네트워크 비용이 발생합니다. 이번 레포지터리에서는 아파치 카프카가 메세지를 저장하는 Topic 구성을 어떻게 하는지 살펴보고, 'rack awareness'을 통한 네트워크 비용 절감 전략에 대해서 소개합니다.

## 아파치 카프카 및 MSK 구조
<img src="/pic/pic1.png" width="50%" height="50%"></img>

카프카는 데이터를 저장할때 토픽을 생성하여 토픽을 기준으로 데이터를 저장합니다. 카프카는 병렬 처리와 성능을 위해서 하나의 토픽을 여러 파티션으로 분산하고, 고가용성을 위해 파티션의 복제본을 구성합니다. 위 그림은 하나의 토픽에 1개의 파티션과 2개의 복제본으로 구성된 구조입니다.

카프카에 데이터를 저장하는 Producer 또는 데이터를 읽는 Consumer는 리더 파티션을 기준으로 데이터를 저장하고 읽습니다. 또한 리더 파티션은 Producer로 부터 데이터를 전달받으면 해당 데이터를 복제본 파티션에 복제하고 브로커에 대한 장애 발생을 대비합니다.

Amazon MSK의 경우 MSK를 생성 할 시 가용영역을 지정하고, 각 가용영역의 배수 만큼 브로커가 생성됩니다. 즉 가용영역의 수를 3개로 지정 할 경우 브로커의 수는 3, 6, 9 등 가용영역의 배수 만큼 브로커가 확장됩니다. Amazon MSK는 Kafka의 *rack awareness*의 설정을 통해서 자동으로 복제 파티션을 다른 AZ에 위치한 브로커로 분산 저장시킵니다. 즉 AZ-1에 위치한 Leader 파티션에 대한 복제 파티션은 AZ-2 또는 AZ-3에 위치하게 됩니다.


위와 같이 아파치 카프카와 Amazon MSK의 고가용성 보장을 위한 구성은 파티션을 여러 AZ에 분산해서 저장하게 합니다. 위 그림과 같이 Consumer가 특정 토픽을 통해서 데이터를 읽을 때, 카프카는 기본적으로 Leader 파티션을 통해 데이터를 가져오며 만약 Consumer와 아파치 카프카간 다른 AZ에 위치 할 경우 **Cross-AZ 통신**이 발생하게 되며 이는 네트워크 트래픽 비용으로 이어집니다.

## Cross-AZ 통신 제거로 비용 절감

### KIP-392

<img src="/pic/pic2.png" width="50%" height="50%"></img>

아파치 카프카와 Amazon MSK의 구조로 인해 발생하는 Cross-AZ 비용을 절감하기 위한 수단으로 [KIP-392](https://cwiki.apache.org/confluence/display/KAFKA/KIP-392%3A+Allow+consumers+to+fetch+from+closest+replica)에서 제시하는 Consumer가 리더 파티션이 아닌 가장 가까운(같은 AZ) 브로커의 파티션에서 데이터를 가져오는 방식으로 Cross-AZ 통신을 제거 할 수 있습니다.

[KIP-392](https://cwiki.apache.org/confluence/display/KAFKA/KIP-392%3A+Allow+consumers+to+fetch+from+closest+replica)에서 제시하는 방법으로는 리더 파티션이 아닌 복제 파티션에서 데이터를 가져 올 경우 커밋된 데이터만 가져오며 이로 인해 Latency가 발생 할 수 있습니다. 그러나 각 복제 파티션에 최신 데이터가 계속 유지 될 수 있도록 복제 파티션의 High Watermark를 달성 할 수 있도록 합니다.

### Out of Range 처리

![Alt text](/pic/pic3.png)

Consumer가 복제 파티션으로부터 커밋 된 데이터만 가져올 경우 우려되는 케이스는 총 4가지 상황이 있습니다. 각 4가지 상황에 대해 설명하고 해당 상황을 대처하는 방법에 대해 소개합니다.

1. **Case.1 : 커밋되지 않은 오프셋**
    - 복제 파티션에 데이터는 저장되었으나, 커밋되지 않은 메세지입니다. 이 경우 Consumer가 데이터를 가져오려고 할 때 *OFFSET_NOT_AVAILABLE* 오류 코드를 반환합니다. 소비자는 재시도를 통해 이 문제를 처리합니다.
2. **Case.2 : 사용할 수 없는 오프셋**
    - 복제 파티션에 데이터가 저장되지 않았지만, 커밋되었다고 한 경우 입니다. 동기화되지 않은 복제본도 리더로부터 계속 가져오게 되며 가져 온 복제본보다 높은 워터마크 값을 받았을 수 있습니다. 이 경우 Consumer에게 재시도를 유발하는 OFFSET_NOT_AVAILABLE도 반환합니다.
3. **Case.3 : 너무 작은 오프셋**
    - 가져오려고 하는 Offset이 offset start보다 앞에 위치하여 가져올 수 없는 경우입니다. 이 경우에는 Consumer가 복제 파티션에서 데이터를 가져 올 때 'earliest' 설정을 통해 offset start보다 앞에 위치하도록 조정하고, 오류가 발생한 offset start 시점부터 데이터를 가져옵니다. 
4. **Case.4 : 너무 큰 오프셋**
    - 가져오려는 오프셋이 복제 파티션에 위치하지 않으며 Commit되지 않은 상태입니다. 이 경우 kafka는 'OFFSET_OUT_OF_RANGE' 에러를 발생시키며 아래의 방법으로 대처합니다.
        
        1. 'OffsetForLeaderEpoch API'을 사용하여 리더 파티션으로부터 복제본 파티션의 오프셋 값과 High Water Makr 값을 최신화합니다.

        2. 만약 offset 잘림이 발생하면, [KIP-320](https://cwiki.apache.org/confluence/display/KAFKA/KIP-320%3A+Allow+fetchers+to+detect+and+handle+log+truncation)을 따라 복구합니다.

## Hands on Lab

### Terraform을 통한 인프라 구성

Git Repository를 Local Client에 Clone 합니다. Local Client는 Mac 또는 Linux 기반의 VM 또는 EC2 환경이면 됩니다.

<pre><code>git clone https://github.com/huhjinsung/aws-msk-reducing-traffic-cost.git</code>
<code>cd aws-msk-reducing-traffic-cost/1_Setup</code>
<code>terraform init</code>
<code>terraform apply -auto-approve </code></pre>

Terraform을 실행하기 위해서는 아래의 Input 값들이 필요합니다. 각 AWS 계정에 따라 Input 을 입력합니다.
| 값 | 내용 |
|---|---|
| AWS Access Key | AWS 계정의 Access Key를 입력합니다. |
| AWS Secret Key | AWS 계정의 Secret Key를 입력합니다. |
| Account ID | AWS 계정의 Account ID를 입력합니다. |

Terraform을 통해 Consumer 생성 시 Kafka Consumer를 통해 데이터를 가져올때의 출력 로그 수준을 변경합니다.
<pre>
<code>log4j.logger.org.apache.kafka.clients.consumer.internals.Fetcher=DEBUG
</code>
</pre>


Terraform을 통해 MSK 클러스터를 생성하며, 아래의 Config를 기반으로 클러스터를 생성합니다.
<pre>
<code>auto.create.topics.enable = true</code>
<code>delete.topic.enable       = true</code>
<code>replica.selector.class    = org.apache.kafka.common.replica.RackAwareReplicaSelector </code>
</pre>

- **replica.selector.class** : 구현하는 정규화된 클래스 이름. ReplicaSelector 브로커는 이 값을 사용하여 선호하는 읽기 복제본을 찾습니다. Apache Kafka 버전 2.4.1 이상을 사용하며 소비자가 가장 가까운 복제본에서 가져오도록 허용하려면 이 속성을 org.apache.kafka.common.replica.RackAwareReplicaSelector로 설정합니다.

Terraform을 통해 MSK 클러스터 생성이 완료되면, MSK 클러스터 엔드포인트를 출력합니다. 해당 값을 메모장에 복사해둡니다.

<pre>
<code>## 예시 </code>
<code>delete.topic.enable       = true</code>
</pre>