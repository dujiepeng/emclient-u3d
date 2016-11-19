//
//  EMSdkLib.m
//  easemob
//
//  Created by lzj on 13/11/2016.
//  Copyright © 2016 EaseMob. All rights reserved.
//

#import "EMSdkLib.h"

@implementation EMSdkLib

static NSString* EM_U3D_OBJECT = @"emsdk_cb_object";


+ (instancetype) sharedSdkLib
{
    static EMSdkLib *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken,^{
        sharedInstance = [[EMSdkLib alloc] init];
        // Do any other initialisation stuff here
        
    });
    
    return sharedInstance;
}

- (void) initializeSDK:(NSString *)appKey
{
    EMOptions *options = [EMOptions optionsWithAppkey:appKey];
//    options.apnsCertName = @"istore_dev";
    [[EMClient sharedClient] initializeSDKWithOptions:options];
    
    [[EMClient sharedClient].chatManager addDelegate:self delegateQueue:nil];
    [[EMClient sharedClient].groupManager addDelegate:self delegateQueue:nil];
}

- (void) applicationDidEnterBackground:(UIApplication *)application
{
    [[EMClient sharedClient] applicationDidEnterBackground:application];
}

- (void) applicationWillEnterForeground:(UIApplication *)application
{
    [[EMClient sharedClient] applicationWillEnterForeground:application];
}

- (int) createAccount:(NSString *)username withPwd:(NSString *)password
{
    EMError *error = [[EMClient sharedClient] registerWithUsername:username password:password];
    if(!error)
        return 0;
    else
        return [error code];
}

- (void) login:(NSString *)username withPwd:(NSString *)password
{
    [[EMClient sharedClient] loginWithUsername:username password:password completion:^(NSString *username, EMError *error){
        NSString *cbName = @"LoginCallback";
        if(!error){
            [self sendSuccessCallback:cbName];
        }else{
            [self sendErrorCallback:cbName withError:error];
        }
    }];
}

- (void) logout:(BOOL)flag
{
    [[EMClient sharedClient] logout:flag completion:^(EMError *error){
        NSString *cbName = @"LogoutCallback";
        if(!error)
        {
            [self sendSuccessCallback:cbName];
        }else{
            [self sendErrorCallback:cbName withError:error];
        }
    
    }];
}

- (void) sendTextMessage:(NSString *)content toUser:(NSString *)to callbackId:(int)callbackId chattype:(int)chattype
{
    EMTextMessageBody *body = [[EMTextMessageBody alloc] initWithText:content];
    NSString *from = [[EMClient sharedClient] currentUsername];
    
    EMMessage *message = [[EMMessage alloc] initWithConversationID:to from:from to:to body:body ext:nil];
    if(chattype == 0)
        message.chatType = EMChatTypeChat;// 设置为单聊消息
    else if (chattype == 1)
        message.chatType = EMChatTypeGroupChat;
    
    [self sendMessage:message CallbackId:callbackId];
}

- (void) sendFileMessage:(NSString *)path toUser:(NSString *)to callbackId:(int)callbackId chattype:(int)chattype
{
    EMFileMessageBody *body = [[EMFileMessageBody alloc] initWithLocalPath:path displayName:[path lastPathComponent]];
    NSString *from = [[EMClient sharedClient] currentUsername];
    
    EMMessage *message = [[EMMessage alloc] initWithConversationID:to from:from to:to body:body ext:nil];
    if(chattype == 0)
        message.chatType = EMChatTypeChat;// 设置为单聊消息
    else if (chattype == 1)
        message.chatType = EMChatTypeGroupChat;
    
    [self sendMessage:message CallbackId:callbackId];
}

- (NSString *) getAllContactsFromServer
{
    EMError *error = nil;
    NSArray *array = [[EMClient sharedClient].contactManager getContactsFromServerWithError:&error];
    if(!error && [array count] > 0)
        return [array componentsJoinedByString:@","];
    return @"";
}

- (NSString *) getAllConversations
{
    NSMutableArray *retArray = [NSMutableArray array];
    NSArray *array = [[EMClient sharedClient].chatManager getAllConversations];
    if([array count] >0)
        for(EMConversation *con in array){
            [retArray addObject:[self conversation2dic:con]];
        }
    return [self toJson:retArray];
}

//group API
- (void) createGroup:(NSString *)groupName desc:(NSString *)desc members:(NSString *)ms reason:(NSString *)reason maxUsers:(int)count type:(int)type callbackId:(int)cbId
{
    EMError *error = nil;
    NSString *cbName = @"CreateGroupCallback";
    EMGroupOptions *setting = [[EMGroupOptions alloc] init];
    setting.maxUsersCount = count;
    setting.style = (EMGroupStyle)type;
    NSArray *arr = [ms componentsSeparatedByString:@","];
    EMGroup *group = [[EMClient sharedClient].groupManager createGroupWithSubject:groupName description:desc invitees:arr message:reason setting:setting error:&error];
    if(!error)
    {
        NSString *json = [self toJson:[self group2dic:group]];
        if(json != nil)
            [self sendSuccessCallback:cbName CallbackId:cbId data:json];
    }else
    {
        [self sendErrorCallback:cbName withError:error];
    }
}

- (void) destroyGroup: (NSString *) groupId callbackId:(int) cbId
{
    EMError *error = nil;
    NSString *cbName = @"DestroyGroupCallback";

    [[EMClient sharedClient].groupManager destroyGroup: groupId error:&error];
    if (!error) {
        [self sendSuccessCallback:cbName CallbackId: cbId];
    } else {
        [self sendErrorCallback:cbName withError:error];
    }
}

- (void) updateGroupSubject:(NSString *) aSubject forGroup:(NSString *)aGroupId callbackId:(int)cbId
{
    NSString *cbName = @"ChangeGroupNameCallback";
    [[EMClient sharedClient].groupManager updateGroupSubject:aSubject forGroup:aGroupId completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];

}
- (void) updateGroupDescription:(NSString *) aDescription forGroup:(NSString *)aGroupId callbackId:(int)cbId
{
    NSString *cbName = @"UpdateGroupDescriptionCallback";
    [[EMClient sharedClient].groupManager updateDescription:aDescription forGroup:aGroupId completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}

- (NSString *)getJoinedGroups
{
    NSArray *groupArray = [[EMClient sharedClient].groupManager getJoinedGroups];
    NSMutableArray *retArray = [NSMutableArray array];
    if ([groupArray count] > 0) {
        for (EMGroup *group in groupArray) {
            [retArray addObject:[self toJson:[self group2dic:group]]];
        }
        return [self toJson:retArray];
    } else {
        return @"";
    }
}

- (NSString *)getGroup:(NSString *)groupId
{
    EMError *error = nil;
    EMGroup *group = [[EMClient sharedClient].groupManager fetchGroupInfo:groupId includeMembersList:YES error:&error];
    if(!error)
    {
        return [self toJson:[self group2dic:group]];
    }
    return @"";
}
- (NSString *)getGroupsWithoutPushNotification
{
    NSString *json = nil;
    EMError *error = nil;
    NSArray *groupArray = [[EMClient sharedClient].groupManager getGroupsWithoutPushNotification:&error];
    if (!error && [groupArray count] > 0) {
        for (EMGroup *group in groupArray) {
            json = [json stringByAppendingString:[self toJson:[self group2dic:group]]];
        }
        return json;
    } else {
        return nil;
    }
}

- (void)getJoinedGroupsFromServer:(int)cbId
{
    NSString *cbName = @"GetJoinedGroupsFromServerCallback";

    [[EMClient sharedClient].groupManager getJoinedGroupsFromServerWithCompletion:^(NSArray *aList, EMError *aError) {
        if (!aError && [aList count] > 0) {
            NSMutableArray *array = [NSMutableArray array];
            for (EMGroup *group in aList) {
                [array addObject:[self group2dic:group]];
            }
            [self sendSuccessCallback:cbName CallbackId: cbId data: [self toJson:array]];
        } else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}

- (void)getGroupSpecificationFromServerById:(NSString *)aGroupId includeMembersList:(BOOL)aIncludeMemberList callbackId:(int)cbId
{
    NSString *cbName = @"GetGroupSpecificationFromServerByIdCallback";
    
    [[EMClient sharedClient].groupManager getGroupSpecificationFromServerByID:aGroupId includeMembersList:aIncludeMemberList completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError && aGroup) {
            NSString *json = nil;
            json = [json stringByAppendingString:[self toJson:[self group2dic:aGroup]]];
            [self sendSuccessCallback:cbName CallbackId: cbId data: json];
        } else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}

- (void)getGroupBlacklistFromServerById:(NSString *)aGroupId callbackId:(int)cbId
{
    NSString *cbName = @"GetBlockedUsersCallback";
    
    [[EMClient sharedClient].groupManager getGroupBlackListFromServerByID:aGroupId completion:^(NSArray *aList, EMError *aError) {
        if (!aError && [aList count] > 0) {
            [self sendSuccessCallback:cbName CallbackId: cbId data: [aList componentsJoinedByString:@","]];
        } else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }else{
            [self sendSuccessCallback:cbName CallbackId: cbId data: @""];
        }
    }];
}

- (void) addMembers:(NSString *)ms toGroup: (NSString *) aGroupId withMessage:(NSString *)message callbackId:(int) cbId
{
    NSString *cbName = @"AddUsersToGroupCallback";
    NSArray *members = [ms componentsSeparatedByString:@","];
    [[EMClient sharedClient].groupManager addMembers:members toGroup:aGroupId message:message completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) removeMembers:(NSString *)ms fromGroup: (NSString *) aGroupId callbackId:(int) cbId
{
    NSString *cbName = @"RemoveUserFromGroupCallback";
    NSArray *members = [ms componentsSeparatedByString:@","];
    [[EMClient sharedClient].groupManager removeMembers:members fromGroup:aGroupId completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) blockMembers:(NSString *)ms fromGroup: (NSString *) aGroupId callbackId:(int) cbId
{
    NSString *cbName = @"BlockUserCallback";
    NSArray *members = [ms componentsSeparatedByString:@","];
    [[EMClient sharedClient].groupManager blockMembers:members fromGroup:aGroupId completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) unblockMembers:(NSString *)ms fromGroup: (NSString *) aGroupId callbackId:(int) cbId
{
    NSString *cbName = @"UnblockUserCallback";
    NSArray *members = [ms componentsSeparatedByString:@","];
    [[EMClient sharedClient].groupManager unblockMembers:members fromGroup:aGroupId completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}

- (void) blockGroupMessage:(NSString *)aGroupId callbackId:(int)cbId
{
    NSString *cbName = @"BlockGroupMessageCallback";
    [[EMClient sharedClient].groupManager blockGroup:aGroupId completion:^(EMGroup *aGroup, EMError *error){
        if(!error)
            [self sendSuccessCallback:cbName CallbackId:cbId];
        else
            [self sendErrorCallback:cbName withError:error];
    }];
}

- (void) unblockGroupMessage:(NSString *)aGroupId callbackId:(int)cbId
{
    NSString *cbName = @"UnblockGroupMessageCallback";
    [[EMClient sharedClient].groupManager unblockGroup:aGroupId completion:^(EMGroup *group, EMError *error){
        if(!error)
            [self sendSuccessCallback:cbName CallbackId:cbId];
        else
            [self sendErrorCallback:cbName withError:error];
    }];
    
}

- (void) requestToJoinGroup:(NSString *)aGroupId withMessage:(NSString *)message callbackId:(int) cbId
{
    NSString *cbName = @"ApplyJoinToGroupCallback";
    [[EMClient sharedClient].groupManager requestToJoinPublicGroup:aGroupId message:message completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) leaveGroup:(NSString *)aGroupId callbackId:(int) cbId
{
    NSString *cbName = @"LeaveGroupCallback";
    [[EMClient sharedClient].groupManager leaveGroup:aGroupId completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}

- (void) approveJoinGroupRequest:(NSString *)aGroupId sender:(NSString *) aUsername callbackId:(int) cbId
{
    NSString *cbName = @"ApproveJoinGroupRequestCallback";
    [[EMClient sharedClient].groupManager approveJoinGroupRequest:aGroupId sender:aUsername completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) declineJoinGroupRequest:(NSString *)aGroupId sender:(NSString *) aUsername reason:(NSString *)aReason callbackId:(int) cbId
{
    NSString *cbName = @"DeclineJoinGroupRequestCallback";
    [[EMClient sharedClient].groupManager declineJoinGroupRequest:aGroupId sender:aUsername reason:aReason completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) acceptInvitationFromGroup:(NSString *)aGroupId inviter:(NSString *) aUsername callbackId:(int) cbId
{
    NSString *cbName = @"AcceptInvitationFromGroupCallback";
    [[EMClient sharedClient].groupManager acceptInvitationFromGroup:aGroupId inviter:aUsername completion:^(EMGroup *aGroup, EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}
- (void) declineInvitationFromGroup:(NSString *)aGroupId inviter:(NSString *) aUsername reason:(NSString *)aReason callbackId:(int) cbId
{
    NSString *cbName = @"DeclineInvitationFromGroupCallback";
    [[EMClient sharedClient].groupManager declineGroupInvitation:aGroupId inviter:aUsername reason:aReason completion:^(EMError *aError) {
        if (!aError) {
            [self sendSuccessCallback:cbName CallbackId: cbId];
        }
        else if (aError){
            [self sendErrorCallback:cbName withError:aError];
        }
    }];
}

//message delegates
- (void)messagesDidReceive:(NSArray *)aMessages
{
    NSMutableArray *array = [NSMutableArray array];
    for(EMMessage *message in aMessages)
    {
        [array addObject:[self message2dic:message]];
    }
    
    NSString *json = [self toJson:array];
    if(json != nil)
    {
        [self sendCallback:@"MessageReceivedCallback" param:json];
    }
}

//group delegates
- (void)groupInvitationDidReceive:(NSString *)aGroupId inviter:(NSString *)aInviter message:(NSString *)aMessage
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:aGroupId forKey:@"groupId"];
    [dic setObject:@"" forKey:@"groupName"];
    [dic setObject:aInviter forKey:@"inviter"];
    [dic setObject:aMessage forKey:@"reason"];
    [self sendCallback:@"InvitationReceivedCallback" param:[self toJson:dic]];
}

- (void)groupInvitationDidAccept:(EMGroup *)aGroup invitee:(NSString *)aInvitee
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:aGroup.groupId forKey:@"groupId"];
    [dic setObject:aInvitee forKey:@"inviter"];
    [dic setObject:@"" forKey:@"reason"];
    [self sendCallback:@"InvitationAcceptedCallback" param:[self toJson:dic]];
}

- (void)groupInvitationDidDecline:(EMGroup *)aGroup invitee:(NSString *)aInvitee reason:(NSString *)aReason
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:aGroup.groupId forKey:@"groupId"];
    [dic setObject:aInvitee forKey:@"inviter"];
    [dic setObject:aReason forKey:@"reason"];
    [self sendCallback:@"InvitationDeclinedCallback" param:[self toJson:dic]];
}

- (void)didJoinGroup:(EMGroup *)aGroup inviter:(NSString *)aInviter message:(NSString *)aMessage
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:aGroup.groupId forKey:@"groupId"];
    [dic setObject:aInviter forKey:@"inviter"];
    [dic setObject:aMessage forKey:@"inviteMessage"];
    [self sendCallback:@"AutoAcceptInvitationFromGroupCallback" param:[self toJson:dic]];
}

- (void)didLeaveGroup:(EMGroup *)aGroup reason:(EMGroupLeaveReason)aReason
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:aGroup.groupId forKey:@"groupId"];
    [dic setObject:aGroup.subject forKey:@"groupName"];
    [self sendCallback:@"UserRemovedCallback" param:[self toJson:dic]];
}


//todo
- (void)joinGroupRequestDidReceive:(EMGroup *)aGroup user:(NSString *)aUsername reason:(NSString *)aReason
{
    
}

- (void)joinGroupRequestDidDecline:(NSString *)aGroupId reason:(NSString *)aReason
{
    
}

- (void)joinGroupRequestDidApprove:(EMGroup *)aGroup
{
    
}

- (void)groupListDidUpdate:(NSArray *)aGroupList
{
    
}

- (void) sendMessage:(EMMessage *)message CallbackId:(int)callbackId
{
    NSString *cbName = @"SendMessageCallback";
    [[EMClient sharedClient].chatManager sendMessage:message progress:^(int progress){
        [self sendInProgressCallback:cbName CallbackId:callbackId Progress:progress];
    } completion:^(EMMessage *message, EMError *error){
        if(error)
            [self sendErrorCallback:cbName CallbackId:callbackId withError:error];
        else
            [self sendSuccessCallback:cbName CallbackId:callbackId];
    }];
}

- (void) sendSuccessCallback:(NSString *)cbName
{
    [self sendCallback:EM_U3D_OBJECT cbName:cbName param:@"{\"on\":\"success\"}"];
}

- (void) sendSuccessCallback:(NSString *)cbName CallbackId:(int) callbackId
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"success" forKey:@"on"];
    [dic setObject:[NSNumber numberWithInt:callbackId] forKey:@"callbackid"];
    NSString *json = [self toJson:dic];
    if(json != nil)
        [self sendCallback:EM_U3D_OBJECT cbName:cbName param:json];
}

- (void) sendSuccessCallback:(NSString *)cbName CallbackId:(int) callbackId data:(NSString *)jsonData
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"success" forKey:@"on"];
    [dic setObject:[NSNumber numberWithInt:callbackId] forKey:@"callbackid"];
    [dic setObject:jsonData forKey:@"data"];
    NSString *json = [self toJson:dic];
    if(json != nil)
        [self sendCallback:EM_U3D_OBJECT cbName:cbName param:json];
}

- (void) sendErrorCallback:(NSString *)cbName withError:(EMError *)error
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"error" forKey:@"on"];
    [dic setObject:[NSNumber numberWithInt:[error code]]  forKey:@"code"];
    [dic setObject:[error errorDescription] forKey:@"message"];
    NSString *json = [self toJson:dic];
    if(json != nil){
        [self sendCallback:EM_U3D_OBJECT cbName:cbName param:json];
    }
}
- (void) sendErrorCallback:(NSString *)cbName CallbackId:(int) callbackId withError:(EMError *)error
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"error" forKey:@"on"];
    [dic setObject:[NSNumber numberWithInt:callbackId] forKey:@"callbackid"];
    [dic setObject:[NSNumber numberWithInt:[error code]]  forKey:@"code"];
    [dic setObject:[error errorDescription] forKey:@"message"];
    NSString *json = [self toJson:dic];
    if(json != nil){
        [self sendCallback:EM_U3D_OBJECT cbName:cbName param:json];
    }
}

- (void) sendInProgressCallback:(NSString *)cbName CallbackId:(int) callbackId Progress:(int)progress
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:@"progress" forKey:@"on"];
    [dic setObject:[NSNumber numberWithInt:callbackId] forKey:@"callbackid"];
    [dic setObject:[NSNumber numberWithInt:progress]  forKey:@"progress"];
    [dic setObject:@"status" forKey:@"status"];
    NSString *json = [self toJson:dic];
    if(json != nil){
        [self sendCallback:EM_U3D_OBJECT cbName:cbName param:json];
    }
}

- (void) sendCallback:(NSString *)objName cbName:(NSString *)cbName param:(NSString *)jsonParam
{
    NSLog(@"Send to objName=%@, cbName=%@, param=%@",objName,cbName,jsonParam);
    UnitySendMessage([objName UTF8String], [cbName UTF8String], [jsonParam UTF8String]);
}

- (void)sendCallback:(NSString *)cbName param:(NSString *)jsonParam
{
    [self sendCallback:EM_U3D_OBJECT cbName:cbName param:jsonParam];
}

- (NSString *)toJson:(id)ocData
{
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:ocData options:0 error:&error];
    if(!error){
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (NSDictionary *) message2dic:(EMMessage *)message
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:message.messageId forKey:@"mMsgId"];
    [dic setObject:message.from forKey:@"mFrom"];
    [dic setObject:message.to forKey:@"mTo"];
    [dic setObject:message.isRead?@"true":@"false" forKey:@"mIsUnread"];
    [dic setObject:@"false" forKey:@"mIsListened"];//TODO
    [dic setObject:message.isReadAcked?@"true":@"false" forKey:@"mIsAcked"];
    [dic setObject:message.isDeliverAcked?@"true":@"false" forKey:@"mIsDelivered"];
    [dic setObject:[NSNumber numberWithLong:message.localTime] forKey:@"mLocalTime"];
    [dic setObject:[NSNumber numberWithLong:message.timestamp] forKey:@"mServerTime"];
    [dic setObject:[NSNumber numberWithInt:message.body.type] forKey:@"mType"];
    [dic setObject:[NSNumber numberWithInt:message.status] forKey:@"mStatus"];
    [dic setObject:[NSNumber numberWithInt:message.direction] forKey:@"mDirection"];
    [dic setObject:[NSNumber numberWithInt:message.chatType] forKey:@"mChatType"];
    
    if (message.body.type == EMMessageBodyTypeFile){
        EMFileMessageBody *body = (EMFileMessageBody *)message.body;
        [dic setObject:body.displayName forKey:@"mDisplayName"];
        [dic setObject:body.secretKey forKey:@"mSecretKey"];
        [dic setObject:body.localPath forKey:@"mLocalPath"];
        [dic setObject:body.remotePath forKey:@"mRemotePath"];
    }
    if(message.body.type == EMMessageBodyTypeText)
    {
        EMTextMessageBody *textBody = (EMTextMessageBody *)message.body;
        [dic setObject:textBody.text forKey:@"mTxt"];
    }
    
    return [NSDictionary dictionaryWithDictionary:dic];
}

- (NSDictionary *) group2dic:(EMGroup *)group
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:group.groupId forKey:@"mGroupId"];
    [dic setObject:group.subject forKey:@"mGroupName"];
    [dic setObject:group.description forKey:@"mDescription"];
    [dic setObject:group.owner forKey:@"mOwner"];
    [dic setObject:[NSNumber numberWithInteger:group.membersCount] forKey:@"mMemCount"];
    if([group.members count] > 0)
        [dic setObject:[group.members componentsJoinedByString:@","] forKey:@"mMembers"];
    else
        [dic setObject:@"" forKey:@"mMembers"];
    [dic setObject:group.isPublic?@"true":@"false" forKey:@"mIsPublic"];
    [dic setObject:@"true" forKey:@"mIsAllowInvites"];//TODO
    [dic setObject:group.isBlocked?@"true":@"false" forKey:@"mIsMsgBlocked"];
    return [NSDictionary dictionaryWithDictionary:dic];
}

- (NSDictionary *) conversation2dic:(EMConversation *)conversation
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [dic setObject:conversation.conversationId forKey:@"mConversationId"];
    [dic setObject:[NSNumber numberWithInt:conversation.type] forKey:@"mConversationType"];
    [dic setObject:[NSNumber numberWithInt:conversation.unreadMessagesCount] forKey:@"mUnreadMsgCount"];
    NSString *ext = [self toJson:conversation.ext];
    if(ext != nil)
        [dic setObject:ext forKey:@"mExt"];
    else
        [dic setObject:@"" forKey:@"mExt"];
    if(conversation.latestMessage != nil)
    {
        NSString *msg = [self toJson:[self message2dic:conversation.latestMessage]];
        [dic setObject:msg forKey:@"mLatesMsg"];
    }else
        [dic setObject:[self toJson:[NSDictionary dictionary]] forKey:@"mLatesMsg"];
    return [NSDictionary dictionaryWithDictionary:dic];
}

@end

// Converts C style string to NSString
NSString* CreateNSString (const char* string)
{
    if (string)
        return [NSString stringWithUTF8String: string];
    else
        return [NSString stringWithUTF8String: ""];
}
// Helper method to create C string copy
char* MakeStringCopy (const char* string)
{
    if (string == NULL)
        return NULL;
    
    char* res = (char*)malloc(strlen(string) + 1);
    strcpy(res, string);
    return res;
}

extern "C" {
    
    //done
    int _createAccount(const char* username, const char*password)
    {
        return [[EMSdkLib sharedSdkLib] createAccount:CreateNSString(username) withPwd:CreateNSString(password)];
    }
    //done
    void _login(const char* username, const char* password)
    {
        [[EMSdkLib sharedSdkLib] login:CreateNSString(username) withPwd:CreateNSString(password)];
    }
    //done
    void _logout(bool flag)
    {
        [[EMSdkLib sharedSdkLib] logout:flag];
    }
    //done
    void _sendTextMessage(const char* content, const char* to, int callbackId,int chattype)
    {
        [[EMSdkLib sharedSdkLib] sendTextMessage:CreateNSString(content) toUser:CreateNSString(to) callbackId:callbackId chattype:chattype];
    }
    //done
    void _sendFileMessage(const char* path, const char* to, int callbackId,int chattype)
    {
        [[EMSdkLib sharedSdkLib] sendFileMessage:CreateNSString(path) toUser:CreateNSString(to) callbackId:callbackId chattype:chattype];
    }
    
    //done
    const char* _getAllContactsFromServer()
    {
        return MakeStringCopy([[[EMSdkLib sharedSdkLib] getAllContactsFromServer] UTF8String]);
    }
    
    //done
    const char* _getAllConversations()
    {
        return MakeStringCopy([[[EMSdkLib sharedSdkLib] getAllConversations] UTF8String]);
    }
    
    //done
    void _createGroup (int callbackId, const char* groupName, const char* desc, const char* strMembers, const char* reason, int maxUsers, int style)
    {
        [[EMSdkLib sharedSdkLib] createGroup:CreateNSString(groupName) desc:CreateNSString(desc) members:CreateNSString(strMembers) reason:CreateNSString(reason) maxUsers:maxUsers type:style callbackId:callbackId];
    }
    
    //done
    void _applyJoinToGroup (int callbackId,const char* groupId, const char* reason)
    {
        [[EMSdkLib sharedSdkLib] requestToJoinGroup:CreateNSString(groupId) withMessage:CreateNSString(reason) callbackId:callbackId];
    }

    //done
    void _destroyGroup(int callbackId, const char* groupId)
    {
        [[EMSdkLib sharedSdkLib] destroyGroup:CreateNSString(groupId) callbackId:callbackId];
    }

    //done
    void _changeGroupName(int callbackId, const char* groupId, const char* subject)
    {
        [[EMSdkLib sharedSdkLib] updateGroupSubject:CreateNSString(subject) forGroup:CreateNSString(groupId) callbackId:callbackId];
    }
 
    void _updateGroupDescription(int callbackId, const char* description, const char* groupId)
    {
        [[EMSdkLib sharedSdkLib] updateGroupSubject:CreateNSString(description) forGroup:CreateNSString(groupId) callbackId:callbackId];
    }

    //done
    const char* _getJoinedGroups()
    {
        return MakeStringCopy([[[EMSdkLib sharedSdkLib] getJoinedGroups] UTF8String]);
    }
    
    //done
    const char* _getGroup(const char* groupId)
    {
        return MakeStringCopy([[[EMSdkLib sharedSdkLib] getGroup:CreateNSString(groupId)] UTF8String]);
    }
    
    //done
    void _getJoinedGroupsFromServer(int callbackId)
    {
        [[EMSdkLib sharedSdkLib] getJoinedGroupsFromServer:callbackId];
    }
    
    void _getGroupSpecificationFromServerById(int callbackId, const char* groupId, bool includeMemberList)
    {
        [[EMSdkLib sharedSdkLib] getGroupSpecificationFromServerById:CreateNSString(groupId) includeMembersList:includeMemberList callbackId:callbackId];
    }
    
    
    //done
    void _getBlockedUsers(int callbackId, const char* groupId)
    {
        [[EMSdkLib sharedSdkLib] getGroupBlacklistFromServerById:CreateNSString(groupId) callbackId:callbackId];
    }
    
    //todo 群主加人调用此方法
    void _addUsersToGroup(int callbackId, const char* toGroup, const char* members)
    {
        
    }
    
    //todo 私有群里，如果开放了群成员邀请，群成员邀请调用下面方法
    void _inviteUser (int callbackId,const char* groupId, const char* beInvitedUsernames, const char* reason)
    {
        
    }
    
    //todo 如果群开群是自由加入的，即group.isMembersOnly()为false，直接join
    void _joinGroup (int callbackId,const char* groupId)
    {
        
    }
    
    //done
    void _removeUserFromGroup(int callbackId, const char* fromGroup, const char* members)
    {
        [[EMSdkLib sharedSdkLib] removeMembers:CreateNSString(members) fromGroup:CreateNSString(fromGroup) callbackId:callbackId];
    }
    
    //done
    void _blockUser(int callbackId, const char* toGroup, const char* members)
    {
        [[EMSdkLib sharedSdkLib] blockMembers:CreateNSString(members) fromGroup:CreateNSString(toGroup) callbackId:callbackId];
    }

    //done
    void _unblockUser(int callbackId, const char* fromGroup, const char* members)
    {
        [[EMSdkLib sharedSdkLib] unblockMembers:CreateNSString(members) fromGroup:CreateNSString(fromGroup) callbackId:callbackId];
    }
    
    //done
    void _blockGroupMessage (int callbackId,const char* groupId)
    {
        [[EMSdkLib sharedSdkLib] blockGroupMessage:CreateNSString(groupId) callbackId:callbackId];
    }
    
    //done
    void _unblockGroupMessage (int callbackId,const char* groupId)
    {
        [[EMSdkLib sharedSdkLib] unblockGroupMessage:CreateNSString(groupId) callbackId:callbackId];
    }
    
    void _requestToJoinGroup(int callbackId, const char* groupId, const char* message)
    {
        [[EMSdkLib sharedSdkLib] requestToJoinGroup:CreateNSString(groupId) withMessage:CreateNSString(message) callbackId:callbackId];
    }
    
    
    //done
    void _leaveGroup(int callbackId, const char* groupId)
    {
        [[EMSdkLib sharedSdkLib] leaveGroup:CreateNSString(groupId) callbackId:callbackId];
    }
    
    void _approveJoinGroupRequest(int callbackId, const char* groupId, const char* sender)
    {
        [[EMSdkLib sharedSdkLib] approveJoinGroupRequest:CreateNSString(groupId) sender:CreateNSString(sender) callbackId:callbackId];
    }
    
    void _declineJoinGroupRequest(int callbackId, const char* groupId, const char* sender, const char* reason)
    {
        [[EMSdkLib sharedSdkLib] declineJoinGroupRequest:CreateNSString(groupId) sender:CreateNSString(sender) reason:CreateNSString(reason) callbackId:callbackId];
    }

    void _acceptInvitationFromGroup(int callbackId, const char* groupId, const char* inviter)
    {
        [[EMSdkLib sharedSdkLib] acceptInvitationFromGroup:CreateNSString(groupId) inviter:CreateNSString(inviter) callbackId:callbackId];
    }
    
    void _declineInvitationFromGroup(int callbackId, const char* groupId, const char* inviter, const char* reason)
    {
        [[EMSdkLib sharedSdkLib] declineInvitationFromGroup:CreateNSString(groupId) inviter:CreateNSString(inviter) reason:CreateNSString(reason) callbackId:callbackId];
    }

}