# LogiPet — MX Master 4 데스크톱 펫 데모

LogiPet은 MX Master 4를 사용하는 동안 함께 걷고 쉬며 하루를 기록하는 Windows·macOS 데스크톱 동반견입니다.

## macOS 버전

macOS 버전은 `LogiPetMac`의 SwiftUI/AppKit 네이티브 앱입니다. Windows 버전의
XP 스타일, 고정 위치 모찌 애니메이션, 커서 방향 보기, 시간대 대사와 말풍선,
클릭·휠 통계, BLE 배터리 탐색 및 Actions Ring 명령을 macOS 방식으로 구현합니다.

- 지원 OS: macOS 13 이상
- Apple Silicon과 Intel 빌드를 GitHub Actions에서 각각 생성
- 최초 실행 시 Bluetooth와 손쉬운 사용 권한 필요
- 활동 기록: `~/Library/Application Support/LogiPet/state.json`
- 커서 좌표나 사용 중인 앱 이름은 저장하지 않음

macOS는 전역 입력 이벤트에서 물리 장치 ID를 제공하지 않기 때문에 현재 통계는
MX Master 4를 포함한 시스템 전체 마우스 입력을 집계합니다. 배터리는 CoreBluetooth로
MX Master 장치를 찾아 표준 Battery Service 값을 읽습니다.

### macOS 로컬 빌드

```bash
cd LogiPetMac
swift test
swift build -c release
```

GitHub의 **Actions → Build macOS app → Run workflow**를 실행하면
`LogiPet-macOS-Apple-Silicon.zip`과 `LogiPet-macOS-Intel.zip`이 Artifacts에 생성됩니다.
태그의 GitHub Release를 발행하면 두 파일이 릴리스에도 자동 첨부됩니다.

## 구현된 기능

- 투명 배경·항상 위에 표시되는 데스크톱 펫 `모찌`
- XP.css 디자인 규칙을 WPF로 이식한 252×230 크기의 컴팩트 UI
- Galmuri11 UI와 Neo둥근모 대사, CC0 골든 리트리버 스프라이트
- Tango 16×16 아이콘과 직접 제작한 강아지·MX Master 4 픽셀 아이콘
- 강아지 클릭/우클릭 시에만 열리는 작은 액션 메뉴
- 필요할 때 위로 펼쳐지는 동행 상태·오늘의 발자국 패널
- 입력 리듬에 따른 기다림·걷기·달리기·앉기·휴식·수면 전환
- 자리 비움과 복귀 인사, 30분·1시간 활동 마일스톤 축하
- 간식 축하, 하이파이브, 함께 스트레칭, 잠깐 놀기, 오늘의 발자국
- Bluetooth LE를 통한 MX Master 4 실제 배터리 자동 감지
- Logitech Raw Input을 통한 마우스 이동 반응과 오늘의 클릭·휠 활동 집계
- Actions Ring 실행 횟수 집계와 매일 자정 자동 초기화
- 배터리 잔량에 따른 표정·대사·놀기 반응 변화
- Actions Ring에 배치할 수 있는 5개 Logi Actions SDK 액션
- 동행 시간, 이동량, 교감 기록과 창 위치 로컬 저장
- 100%, 125%, 150%, 200% 배율을 고려한 WPF DPI 레이아웃과 nearest-neighbor 아이콘 렌더링

## 내일 데모 실행

1. 루트 폴더의 `Run-LogiPet.cmd`를 실행합니다.
2. 강아지를 클릭하거나 우클릭하면 `밥 / 놀이 / 잠 / 상태` 메뉴가 열립니다.
3. Logi Options+에서 MX Master 4 → Actions Ring → 사용자 지정을 엽니다.
4. **모든 액션 → 설치된 플러그인 → LogiPet Desktop Companion**을 선택합니다.
5. 아래 LogiPet 액션 중 자주 쓰는 기능을 원하는 칸이나 Actions Ring 폴더에 배치합니다.

### Actions Ring에서 선택할 수 있는 모찌 액션

- `Celebrate with Snack` — 간식 먹기
- `Give Water` — 물 마시기
- `High Five` — 짖기와 점프로 축하
- `Come Here` — 이리 와
- `Zoomies` — 신나게 우다다
- `Speak` — 짖어
- `Sit` — 앉아
- `Lie Down` — 엎드려
- `Take a Nap` — 잠깐 낮잠
- `Scratch` — 몸 긁기
- `Stretch Together` — 함께 스트레칭
- `Quick Play` — 잠깐 놀기
- `Today's Activity` — 오늘 활동 통계

현재 PC에는 앱이 `%LOCALAPPDATA%\LogiPet`에 배치되어 있고, 플러그인은 개발 링크 방식으로 연결되어 있습니다.

## 배터리 반응

- 70% 이상: 달리기 애니메이션과 활발한 점프
- 30~69%: 편안한 대기 애니메이션
- 15~29%: 엎드리기 애니메이션과 충전 안내
- 15% 미만: 잠든 자세로 격한 놀기를 거절하고 충전을 요청
- 새로고침 시 배터리가 이전 값보다 상승: 스트레칭, 작은 번개, 기쁨 점프

배터리 연동은 Windows에서 MX Master 4가 Bluetooth로 페어링되어 있어야 합니다. 마우스가 잠들어 배터리를 읽지 못하면 마우스를 움직인 후 앱의 `배터리 확인`을 실행하세요.

## 오늘 활동

`오늘 활동`에서 왼쪽 클릭, 오른쪽 클릭, 휠 클릭, Actions Ring 실행,
휠 회전 횟수와 휠 이동 거리 추정치를 바로 확인할 수 있습니다. 기록은
`%LOCALAPPDATA%\LogiPet\state.json`에만 저장되고 날짜가 바뀌면 초기화됩니다.
커서 좌표나 사용한 앱 이름은 저장하지 않습니다.

## 다시 빌드하기

```powershell
dotnet build .\LogiPetApp\LogiPetApp.csproj -c Release
dotnet build .\LogiPetPlugin\LogiPetPlugin.sln -c Release -p:SkipPluginReload=true
dotnet publish .\LogiPetApp\LogiPetApp.csproj -c Release -o .\dist\LogiPet
```

배포본은 `dist\LogiPet`, 플러그인 패키지는 `dist\LogiPet.lplug4`에 있습니다. 개발 PC에 다시 연결할 때는 관리자 PowerShell에서 `Install-LogiPet-Dev.ps1`을 실행할 수 있습니다.

## 외부 리소스

외부 리소스의 출처와 라이선스는 `THIRD_PARTY_NOTICES.md`에 기록되어 있으며,
원문 라이선스는 `ThirdParty` 폴더에 보존되어 있습니다. Microsoft에서 추출한
Windows XP 원본 로고, 아이콘, 배경, 사운드 및 Tahoma·굴림·돋움 폰트 파일은
포함하지 않습니다.
