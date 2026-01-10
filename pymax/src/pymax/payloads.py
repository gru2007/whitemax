"""
Payloads для API Max.RU - без pydantic, используем dataclasses.
"""
from dataclasses import dataclass, field, asdict
from typing import Any, Literal
from enum import Enum
import json

from pymax.static.constant import (
    DEFAULT_APP_VERSION,
    DEFAULT_BUILD_NUMBER,
    DEFAULT_CLIENT_SESSION_ID,
    DEFAULT_DEVICE_LOCALE,
    DEFAULT_DEVICE_NAME,
    DEFAULT_DEVICE_TYPE,
    DEFAULT_LOCALE,
    DEFAULT_OS_VERSION,
    DEFAULT_SCREEN,
    DEFAULT_TIMEZONE,
    DEFAULT_USER_AGENT,
)
from pymax.static.enum import AttachType, AuthType, Capability, ContactAction, ReadAction


def to_camel(string: str) -> str:
    """Преобразует snake_case в camelCase."""
    parts = string.split("_")
    if not parts:
        return string
    return parts[0] + "".join(word.capitalize() for word in parts[1:])


def to_dict_camel(obj: Any, exclude_none: bool = False) -> dict[str, Any]:
    """Преобразует объект в словарь с camelCase ключами."""
    # Обрабатываем Enum - преобразуем в их значения
    if isinstance(obj, Enum):
        return obj.value
    
    if isinstance(obj, dict):
        result = {to_camel(k): to_dict_camel(v, exclude_none) for k, v in obj.items()}
        if exclude_none:
            result = {k: v for k, v in result.items() if v is not None}
        return result
    elif isinstance(obj, list):
        return [to_dict_camel(item, exclude_none) for item in obj]
    elif hasattr(obj, "__dict__"):
        # Для dataclass объектов
        data = asdict(obj) if hasattr(obj, "__dataclass_fields__") else obj.__dict__
        result = {to_camel(k): to_dict_camel(v, exclude_none) for k, v in data.items() if not k.startswith("_")}
        if exclude_none:
            result = {k: v for k, v in result.items() if v is not None}
        return result
    else:
        return obj


@dataclass
class BaseWebSocketMessage:
    ver: Literal[10, 11] = 11
    cmd: int = 0
    seq: int = 0
    opcode: int = 0
    payload: dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self, exclude_none: bool = False) -> dict[str, Any]:
        """Возвращает словарь с camelCase ключами."""
        return to_dict_camel(self, exclude_none)


@dataclass
class UserAgentPayload:
    device_type: str = DEFAULT_DEVICE_TYPE
    locale: str = DEFAULT_LOCALE
    device_locale: str = DEFAULT_DEVICE_LOCALE
    os_version: str = DEFAULT_OS_VERSION
    device_name: str = DEFAULT_DEVICE_NAME
    header_user_agent: str = DEFAULT_USER_AGENT
    app_version: str = DEFAULT_APP_VERSION
    screen: str = DEFAULT_SCREEN
    timezone: str = DEFAULT_TIMEZONE
    client_session_id: int = DEFAULT_CLIENT_SESSION_ID
    build_number: int = DEFAULT_BUILD_NUMBER
    
    def to_dict(self, exclude_none: bool = False) -> dict[str, Any]:
        """Возвращает словарь с camelCase ключами."""
        return to_dict_camel(self, exclude_none)


@dataclass
class RequestCodePayload:
    phone: str = ""
    type: AuthType = AuthType.START_AUTH
    language: str = "ru"
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SendCodePayload:
    token: str = ""
    verify_code: str = ""
    auth_token_type: AuthType = AuthType.CHECK_CODE
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SyncPayload:
    interactive: bool = True
    token: str = ""
    chats_sync: int = 0
    contacts_sync: int = 0
    presence_sync: int = 0
    drafts_sync: int = 0
    chats_count: int = 40
    user_agent: UserAgentPayload = field(default_factory=lambda: UserAgentPayload())
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ReplyLink:
    type: str = "REPLY"
    message_id: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class UploadPayload:
    count: int = 1
    profile: bool = False
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class AttachPhotoPayload:
    _type: AttachType = AttachType.PHOTO
    photo_token: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        # to_dict_camel автоматически обрабатывает Enum, но нужно сохранить имя поля _type (не camelCase)
        d = asdict(self)
        d["type"] = self._type.value if isinstance(self._type, Enum) else str(self._type)
        del d["_type"]  # Удаляем _type, так как заменяем на type
        return to_dict_camel(d)


@dataclass
class VideoAttachPayload:
    _type: AttachType = AttachType.VIDEO
    video_id: int = 0
    token: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        # to_dict_camel автоматически обрабатывает Enum, но нужно сохранить имя поля _type (не camelCase)
        d = asdict(self)
        d["type"] = self._type.value if isinstance(self._type, Enum) else str(self._type)
        del d["_type"]  # Удаляем _type, так как заменяем на type
        return to_dict_camel(d)


@dataclass
class AttachFilePayload:
    _type: AttachType = AttachType.FILE
    file_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        # to_dict_camel автоматически обрабатывает Enum, но нужно сохранить имя поля _type (не camelCase)
        d = asdict(self)
        d["type"] = self._type.value if isinstance(self._type, Enum) else str(self._type)
        del d["_type"]  # Удаляем _type, так как заменяем на type
        return to_dict_camel(d)


@dataclass
class MessageElement:
    type: str = ""
    from_: int = 0
    length: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["from"] = d.pop("from_")
        return to_dict_camel(d)


@dataclass
class SendMessagePayloadMessage:
    text: str = ""
    cid: int = 0
    elements: list[MessageElement] = field(default_factory=list)
    attaches: list[AttachPhotoPayload | AttachFilePayload | VideoAttachPayload] = field(default_factory=list)
    link: ReplyLink | None = None
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SendMessagePayload:
    chat_id: int = 0
    message: SendMessagePayloadMessage = field(default_factory=SendMessagePayloadMessage)
    notify: bool = False
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class EditMessagePayload:
    chat_id: int = 0
    message_id: int = 0
    text: str = ""
    elements: list[MessageElement] = field(default_factory=list)
    attaches: list[AttachPhotoPayload | AttachFilePayload | VideoAttachPayload] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class DeleteMessagePayload:
    chat_id: int = 0
    message_ids: list[int] = field(default_factory=list)
    for_me: bool = False
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class FetchContactsPayload:
    contact_ids: list[int] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class FetchHistoryPayload:
    chat_id: int = 0
    from_time: int = 0
    forward: int = 0
    backward: int = 200
    get_messages: bool = True
    
    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["from"] = d.pop("from_time")
        return to_dict_camel(d)


@dataclass
class ChangeProfilePayload:
    first_name: str = ""
    last_name: str | None = None
    description: str | None = None
    photo_token: str | None = None
    avatar_type: str = "USER_AVATAR"
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ResolveLinkPayload:
    link: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class PinMessagePayload:
    chat_id: int = 0
    notify_pin: bool = False
    pin_message_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class CreateGroupAttach:
    _type: Literal["CONTROL"] = "CONTROL"
    event: str = "new"
    chat_type: str = "CHAT"
    title: str = ""
    user_ids: list[int] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        d = asdict(self)
        d["_type"] = self._type
        return to_dict_camel(d)


@dataclass
class CreateGroupMessage:
    cid: int = 0
    attaches: list[CreateGroupAttach] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class CreateGroupPayload:
    message: CreateGroupMessage = field(default_factory=CreateGroupMessage)
    notify: bool = True
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class InviteUsersPayload:
    chat_id: int = 0
    user_ids: list[int] = field(default_factory=list)
    show_history: bool = False
    operation: str = "add"
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class RemoveUsersPayload:
    chat_id: int = 0
    user_ids: list[int] = field(default_factory=list)
    operation: str = "remove"
    clean_msg_period: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ChangeGroupSettingsOptions:
    ONLY_OWNER_CAN_CHANGE_ICON_TITLE: bool | None = None
    ALL_CAN_PIN_MESSAGE: bool | None = None
    ONLY_ADMIN_CAN_ADD_MEMBER: bool | None = None
    ONLY_ADMIN_CAN_CALL: bool | None = None
    MEMBERS_CAN_SEE_PRIVATE_LINK: bool | None = None
    
    def to_dict(self) -> dict[str, Any]:
        return {k: v for k, v in asdict(self).items() if v is not None}


@dataclass
class ChangeGroupSettingsPayload:
    chat_id: int = 0
    options: ChangeGroupSettingsOptions = field(default_factory=ChangeGroupSettingsOptions)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ChangeGroupProfilePayload:
    chat_id: int = 0
    theme: str | None = None
    description: str | None = None
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class GetGroupMembersPayload:
    type: Literal["MEMBER"] = "MEMBER"
    marker: int | None = None
    chat_id: int = 0
    count: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SearchGroupMembersPayload:
    type: Literal["MEMBER"] = "MEMBER"
    query: str = ""
    chat_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class NavigationEventParams:
    action_id: int = 0
    screen_to: int = 0
    screen_from: int | None = None
    source_id: int = 0
    session_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class NavigationEventPayload:
    event: str = ""
    time: int = 0
    type: str = "NAV"
    user_id: int = 0
    params: NavigationEventParams = field(default_factory=NavigationEventParams)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class NavigationPayload:
    events: list[NavigationEventPayload] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class GetVideoPayload:
    chat_id: int = 0
    message_id: int | str = 0
    video_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class GetFilePayload:
    chat_id: int = 0
    message_id: str | int = 0
    file_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SearchByPhonePayload:
    phone: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class JoinChatPayload:
    link: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ReactionInfoPayload:
    reaction_type: str = "EMOJI"
    id: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class AddReactionPayload:
    chat_id: int = 0
    message_id: str = ""
    reaction: ReactionInfoPayload = field(default_factory=ReactionInfoPayload)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class GetReactionsPayload:
    chat_id: int = 0
    message_ids: list[str] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class RemoveReactionPayload:
    chat_id: int = 0
    message_id: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ReworkInviteLinkPayload:
    revoke_private_link: bool = True
    chat_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ContactActionPayload:
    contact_id: int = 0
    action: ContactAction = ContactAction.ADD
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class RegisterPayload:
    last_name: str | None = None
    first_name: str = ""
    token: str = ""
    token_type: AuthType = AuthType.REGISTER
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class CreateFolderPayload:
    id: str = ""
    title: str = ""
    include: list[int] = field(default_factory=list)
    filters: list[Any] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class GetChatInfoPayload:
    chat_ids: list[int] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class GetFolderPayload:
    folder_sync: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class UpdateFolderPayload:
    id: str = ""
    title: str = ""
    include: list[int] = field(default_factory=list)
    filters: list[Any] = field(default_factory=list)
    options: list[Any] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class DeleteFolderPayload:
    folder_ids: list[str] = field(default_factory=list)
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class LeaveChatPayload:
    chat_id: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class FetchChatsPayload:
    marker: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class ReadMessagesPayload:
    type: ReadAction = ReadAction.READ_MESSAGE
    chat_id: int = 0
    message_id: str = ""
    mark: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class CheckPasswordChallengePayload:
    track_id: str = ""
    password: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class CreateTrackPayload:
    type: int = 0
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SetPasswordPayload:
    track_id: str = ""
    password: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SetHintPayload:
    track_id: str = ""
    hint: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SetTwoFactorPayload:
    expected_capabilities: list[Capability] = field(default_factory=list)
    track_id: str = ""
    password: str = ""
    hint: str | None = None
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class RequestEmailCodePayload:
    track_id: str = ""
    email: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)


@dataclass
class SendEmailCodePayload:
    track_id: str = ""
    verify_code: str = ""
    
    def to_dict(self) -> dict[str, Any]:
        return to_dict_camel(self)
