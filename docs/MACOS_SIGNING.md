# macOS Developer ID 서명과 공증

LogiPet의 macOS Release ZIP은 GitHub Actions에서 Developer ID로 서명하고
Apple notary service에 제출한 뒤, 공증 티켓을 앱에 staple하여 생성합니다.

## 필요한 Apple 항목

- 활성 Apple Developer Program 멤버십
- `Developer ID Application` 인증서와 개인 키를 내보낸 `.p12` 파일
- App Store Connect API의 공증용 `.p8` 개인 키, Key ID, Issuer ID

인증서나 개인 키를 저장소에 커밋하거나 채팅으로 전달하지 마세요.

## GitHub Actions 비밀 변수

저장소의 **Settings → Secrets and variables → Actions**에서 다음 Repository
secret 다섯 개를 등록합니다.

| 이름 | 값 |
| --- | --- |
| `APPLE_DEVELOPER_ID_APPLICATION_P12_BASE64` | `.p12` 파일의 Base64 문자열 |
| `APPLE_DEVELOPER_ID_APPLICATION_P12_PASSWORD` | `.p12` 내보내기 암호 |
| `APPLE_NOTARY_PRIVATE_KEY_P8_BASE64` | `AuthKey_*.p8` 파일의 Base64 문자열 |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API Key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect API Issuer ID |

Mac에서 파일을 Base64 문자열로 복사할 수 있습니다.

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
base64 -i AuthKey_KEYID.p8 | pbcopy
```

## 공증된 Release ZIP 생성

1. GitHub의 **Actions → Build macOS app → Run workflow**를 엽니다.
2. `release_tag`에 기존 Release 태그(예: `v1.1.0`)를 입력합니다.
3. Apple Silicon과 Intel 작업이 모두 성공했는지 확인합니다.
4. 해당 Release의 macOS ZIP 두 개가 교체되었는지 확인합니다.

Release 업로드에서는 다섯 비밀 변수가 모두 없으면 작업이 실패하도록 설정되어
있습니다. 일반 push/PR 검증에서는 비밀 변수가 없을 때 ad-hoc 서명 빌드를
생성하지만 Release에는 업로드하지 않습니다.

관련 공식 문서:

- [Apple Developer ID](https://developer.apple.com/support/developer-id/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
