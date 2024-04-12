# aws-msk-reducing-traffic-cost

## 개요
이번 레포지터리에서는 AWS의 관리형 아파치 카프카 서비스인 Amazon MSK를 사용하면서 발생하는 트래픽 비용을 줄이는 전략에 대해서 소개합니다. AWS를 사용할 경우 가용영역(AZ)간 통신 시 트래픽 비용이 발생하며, Amazon MSK의 경우 여러 가용영역(2개 or 3개)에 걸쳐 브로커를 배치합니다. 만약 AZ-a에 위치한 Consumer가 AZ-c에 위치한 MSK 브로커에서 데이터를 읽을 경우 AZ간 트래픽이 발생하며 이로 인한 네트워크 비용이 발생합니다. 이번 레포지터리에서는 아파치 카프카가 메세지를 저장하는 Topic 구성을 어떻게 하는지 살펴보고, 'rack awareness'을 통한 네트워크 비용 절감 전략에 대해서 소개합니다.

## 아파치 카프카 및 MSK 구조
<img src="/pic/pic1.png" width="50%" height="50%"></img>

카프카는 데이터를 저장할때 토픽을 생성하여 토픽을 기준으로 데이터를 저장합니다. 카프카는 병렬 처리와 성능을 위해서 하나의 토픽을 여러 파티션으로 분산하고, 고가용성을 위해 파티션의 복제본을 구성합니다. 위 그림은 하나의 토픽에 1개의 파티션과 2개의 복제본으로 구성된 구조입니다.

카프카에 데이터를 저장하는 Producer 또는 데이터를 읽는 Consumer는 리더 파티션을 기준으로 데이터를 저장하고 읽습니다. 또한 리더 파티션은 Producer로 부터 데이터를 전달받으면 해당 데이터를 복제본 파티션에 복제하고 브로커에 대한 장애 발생을 대비합니다.

Amazon MSK의 경우 MSK를 생성 할 시 가용영역을 지정하고, 각 가용영역의 배수 만큼 브로커가 생성됩니다. 즉 가용영역의 수를 3개로 지정 할 경우 브로커의 수는 3, 6, 9 등 가용영역의 배수 만큼 브로커가 확장됩니다. 위와 같은 상황에서 리더 파티션은 AZ-2에 위치하고, Cosumer가 AZ-3에 위치 할 때 Cross-AZ 통신이 발생하고 이로 인한 가용 영역간 트래픽 비용이 발생합니다.

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
3. **Case.3 :**
4. **Case.4 :**