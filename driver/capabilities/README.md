# Capabilities

이 폴더는 RuleGen profile에서 사용하는 custom capability 정의와 presentation을 둡니다.

현재 namespace는 `earthpilot19519`로 고정되어 있습니다. profile은 create/delete/status capability를 분리해서 사용하고, `rulegenMode`와 `templateId`는 detailView가 아니라 device settings preference로 둡니다.

`translations/`에는 active custom capability의 `en`/`ko` translation 자산을 둡니다. presentation label과 static alternatives는 `{{i18n...}}` 참조를 사용하고, driver가 emit하는 dashboard/status HTML은 `driver/src/runtime_i18n.lua`와 profile의 `Status Language` preference가 담당합니다.

## 필요한 capability 역할

| Capability | 역할 |
| --- | --- |
| `earthpilot19519.rulegenKnobLevelCreate` | MVP create profile의 Slot 1/2 selector, 후보 새로고침, Rule 생성 버튼 |
| `earthpilot19519.rulegenTwoSlotOneEnumCreate` | reusable `two_slot_one_enum` create profile의 Slot 1/2 selector, enum param dropdown, 후보 새로고침, Rule 생성 버튼 |
| `earthpilot19519.rulegenTwoSlotTwoEnumCreate` | reusable `two_slot_two_enum` create profile의 Slot 1/2 selector, enum param dropdown 2개, 후보 새로고침, Rule 생성 버튼 |
| `earthpilot19519.rulegenRuleSelect` | delete profile의 owned Rule selector, Rule 목록 새로고침, Rule 삭제 버튼 |
| `earthpilot19519.rulegenTemplateIntroCard` | create detailView 맨 위에 표시하는 template 소개 HTML card |
| `earthpilot19519.rulegenStatusCard` | main component dashboard용 짧은 status text |
| `earthpilot19519.rulegenStatusPanel` | 별도 `status` component detailView용 HTML status panel |

`earthpilot19519.rulegenRuleDelete`는 초기 delete selector 실험에 사용한 legacy capability입니다. SmartThings 계정 cloud에는 남아 있을 수 있지만, 현재 driver package/profile/script/handler의 active surface에서는 사용하지 않습니다.
`earthpilot19519.rulegenStatus`는 초기 단순 문자열 status에 사용한 legacy capability입니다. SmartThings 계정 cloud에는 남아 있을 수 있지만, 현재 active profile에서는 `rulegenStatusCard`를 사용합니다.

## 설계 방향

- 동적 후보 dropdown은 `supportedValues` 배열 attribute와 string command argument를 사용합니다.
- template마다 capability를 새로 만들지 않고, 재사용 가능한 create UI shape마다 capability/profile을 둡니다.
- delete Rule selector는 SmartThings 공식 presentation list 패턴에 맞춰 `Rule 1`~`Rule 20`을 정적 alternatives로 두고, 현재 owned Rule만 `supportedValues`로 활성화합니다.
- create detailView의 template 소개는 `intro` component의 `rulegenTemplateIntroCard.result.value.html`에 표시하고, delete profile에는 포함하지 않습니다.
- detailView status는 EdgeBridge Agent의 HTTP result card와 같은 별도 component + detail-only HTML-valued state 패턴을 쓴다. `rulegenStatusPanel` presentation은 dashboard states 없이 `{{result.value.html}}`만 detailView에 바인딩하고, driver는 escaped HTML 문자열을 `status` component에 emit한다.
- 앱에 보이는 `selectionKey`는 label 기반이며, `deviceId/componentId/ruleId`는 driver field에만 저장합니다.
- create/delete UI는 하나의 detailView에 섞지 않고, `profile_manager.lua`가 mode/template 설정에 맞는 profile을 요청합니다.

## fallback 아이디어

SmartThings 앱에서 profile/presentation cache 문제로 dropdown 검증이 막히면 임시로 다음 fallback을 고려합니다.

1. 후보를 status text에 번호 목록으로 표시.
2. textField/numberField로 번호 입력.
3. 입력 번호를 candidate cache에서 deviceId/componentId로 해석.

단, MVP 목표 UX는 dropdown입니다.
