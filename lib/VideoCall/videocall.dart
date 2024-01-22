import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pip_view/pip_view.dart';
import 'package:progress_indicators/progress_indicators.dart';
import 'package:provider/provider.dart';

import 'package:doctro_patient/Screen/Screens/Home.dart';
import 'package:doctro_patient/VideoCall/overlay_handler.dart';
import 'package:doctro_patient/VideoCall/overlay_service.dart';
import 'package:doctro_patient/api/base_model.dart';
import 'package:doctro_patient/api/network_api.dart';
import 'package:doctro_patient/api/retrofit_Api.dart';
import 'package:doctro_patient/api/server_error.dart';
import 'package:doctro_patient/const/Palette.dart';
import 'package:doctro_patient/const/prefConstatnt.dart';
import 'package:doctro_patient/const/preference.dart';
import 'package:doctro_patient/model/user_detail_model.dart';
import 'package:doctro_patient/model/video_call_model.dart';

class VideoCall extends StatefulWidget {
  final int? doctorId;
  final String? flag;

  VideoCall({this.doctorId, this.flag});

  @override
  _VideoCallState createState() => _VideoCallState();
}

class _VideoCallState extends State<VideoCall> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool muted = false;
  bool mutedVideo = false;
  late RtcEngine _engine;
  String? appId = SharedPreferenceHelper.getString(Preferences.agoraAppId);
  String? token = "";
  String? channelName = "";
  int? callDuration = 0;
  bool? timeOut = false;
  int uid = 0;
  ChannelMediaOptions options = const ChannelMediaOptions(
    clientRoleType: ClientRoleType.clientRoleBroadcaster,
    channelProfile: ChannelProfileType.channelProfileCommunication,
  );

  @override
  void initState() {
    debugPrint("Doctor ID : ${widget.doctorId}\tFlag : ${widget.flag}");
    super.initState();
    if (widget.flag == "InComming") {
      callApiUserProfile();
    } else if (widget.flag == "Cut") {
      callApiUserProfile();
    } else {
      callApiVideoCallToken();
    }
    offset = const Offset(20.0, 50.0);
  }

  Offset offset = Offset.zero;

  Widget _toolbar() {
    return Consumer<OverlayHandlerProvider>(
      builder: (context, overlayProvider, _) {
        return Container(
          alignment: Alignment.bottomCenter,
          padding: EdgeInsets.symmetric(vertical: overlayProvider.inPipMode == true ? 20 : 45),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RawMaterialButton(
                  onPressed: _onToggleMute,
                  child: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: muted ? Palette.white : Palette.blue,
                    size: overlayProvider.inPipMode == true ? 12.0 : 15.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: muted ? Palette.blue : Palette.white,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 12.0),
                ),
              ),
              Expanded(
                child: RawMaterialButton(
                  onPressed: () => _onCallEnd(context),
                  child: Icon(
                    Icons.call_end,
                    color: Palette.white,
                    size: overlayProvider.inPipMode == true ? 15.0 : 30.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Palette.red,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 15.0),
                ),
              ),
              Expanded(
                child: RawMaterialButton(
                  onPressed: _onSwitchCamera,
                  child: Icon(
                    Icons.switch_camera,
                    color: Palette.blue,
                    size: overlayProvider.inPipMode == true ? 12.0 : 15.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Palette.white,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 12.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? callTime = "";
  String? callDate = "";

  void _onCallEnd(BuildContext context) async {
    await _engine.leaveChannel();
    setState(() { 
      _localUserJoined = false;
      _remoteUid = null;
    });
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = await createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: appId!,
    ));
    await _engine.enableVideo();

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          print("Local user uid:${connection.localUid} joined the channel");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          print("Remote user uid:$remoteUid joined the channel");
          DateTime now = DateTime.now();
          callTime = DateFormat('h:mm a').format(now);
          callDate = DateFormat('yyyy-MM-dd').format(now);
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          print("Remote user uid:$remoteUid left the channel");
          setState(() {
            _remoteUid = null;
            _engine.leaveChannel();
            Fluttertoast.showToast(msg: "Call Ended",toastLength: Toast.LENGTH_SHORT);
          });
        },
        onLeaveChannel: (RtcConnection connection, RtcStats detail) {
          if (widget.flag == "InComming") {
            setState(() {
              callDuration = detail.duration;
              if (callTime != "" && callDate != "") {
                Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => Home()));
              } else {
                Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => Home()));
              }
            });
          } else if (widget.flag == "Cut") {
            setState(() {
              callDuration = detail.duration;
              if (callTime != "" && callDate != "") {
                Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => Home()));
              } else {
                Navigator.pushReplacement( context, MaterialPageRoute(builder: (context) => Home()));
              }
            });
          } else {
            setState(() {
              callDuration = detail.duration;
              OverlayService().removeVideosOverlay(context, VideoCall(doctorId: widget.doctorId));
            });
          }
        },
      ),
    );

    await _engine.startPreview();
    _engine.joinChannel(
      token: '$token',
      channelId: '$channelName',
      uid: uid,
      options: options,
    );
  }

  @override
  void dispose() async {
    super.dispose();
    await _engine.leaveChannel();
    await _engine.release();
  }


  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return PIPView(
      builder: (context, isFloating) {
        return Scaffold(
          body: Consumer<OverlayHandlerProvider>(
            builder: (context, overlayProvider, _) {
              return InkWell(
                onTap: () {
                  Provider.of<OverlayHandlerProvider>(context, listen: false).disablePip();
                },
                child: Stack(
                  children: [
                    Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: _remoteVideo(),
                      ),
                    ),
                    widget.flag == "Cut"
                        ? Container()
                        : Stack(
                      children: [
                        Positioned(
                          left: offset.dx,
                          top: offset.dy,
                          child: GestureDetector(
                            onPanUpdate: (details) {
                              setState(() {
                                if (offset.dx > 0.0 && (offset.dx + 150) < width && offset.dy > 0.0 && (offset.dy + 200) < height) {
                                  offset = Offset(offset.dx + details.delta.dx, offset.dy + details.delta.dy);
                                } else {
                                  offset = Offset(details.delta.dx + 20, details.delta.dy + 50);
                                }
                              });
                            },
                            child: Consumer<OverlayHandlerProvider>(
                              builder: (context, overlayProvider, _) {
                                return SizedBox(
                                  width: overlayProvider.inPipMode == true ? 80 : 150,
                                  height: overlayProvider.inPipMode == true ? 80 : 200,
                                  child: Center(
                                    child: _localUserJoined
                                        ? _localPreview()
                                        : const CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    _toolbar(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _localPreview() {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _remoteVideo() {
    print('App ID : $appId\tFlag: ${widget.flag}\nChannel Name: ${channelName}\nTocken : ${token}\nRemote UID : ${_remoteUid}');
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      );
    } else {
      if (widget.flag == "InComming") {
        return ScalingText(
          'Connecting...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      } else if (widget.flag == "Cut") {
        return ScalingText(
          'Call Ended...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      } else {
        return ScalingText(
          'Ringing...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      }
    }
  }

  Future<BaseModel<VideoCallModel>> callApiVideoCallToken() async {
    VideoCallModel response;
    Map<String, dynamic> body = {
      "to_id": widget.doctorId,
    };
    try {
      response = await RestClient(RetroApi().dioData()).videoCallRequest(body);
      if (response.success == true) {
        channelName = response.data!.cn;
        token = response.data!.token;
        await initAgora();
      }
      setState(() {});
    } catch (error, stacktrace) {
      print("Exception occur: $error stackTrace: $stacktrace");
      return BaseModel()..setException(ServerError.withError(error: error));
    }
    return BaseModel()..data = response;
  }

  Future<BaseModel<UserDetail>> callApiUserProfile() async {
    UserDetail response;
    try {
      response = await RestClient(RetroApi().dioData()).userDetailRequest();
      if(response.status == 1){
        channelName = response.channelName!;
        token = response.agoraToken;
        await initAgora();
      }
      setState(() {});
    } catch (error, stacktrace) {
      print("Exception occur: $error stackTrace: $stacktrace");
      return BaseModel()..setException(ServerError.withError(error: error));
    }
    return BaseModel()..data = response;
  }
}

///       CUSTOM CODE
///
/*
/*
  final String appId = "708f2e13a2cf456e8b83b02c1dbc1798";

  String channelName = "";
  String token = "006708f2e13a2cf456e8b83b02c1dbc1798IACzMW7c52VRV+HeFqNr7h8LNsvzIbNW64z4H3IxckeB23ybuowAAAAAIgC+P8EDAn51ZQQAAQCqT3RlAwCqT3RlAgCqT…";


  int uid = 0; // uid of the local user

  int? _remoteUid; // uid of the remote user
  bool _isJoined = false; // Indicates if the local user has joined the channel
  late RtcEngine agoraEngine; // Agora engine instance

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey
  = GlobalKey<ScaffoldMessengerState>(); // Global key to access the scaffold

  showMessage(String message) {
        scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(message),
        ));
    }

  @override
  void initState() {
      super.initState();
      // Set up an instance of Agora engine
      setupVideoSDKEngine();
      if (widget.flag == "InComming") {
        callApiUserProfile();
      } else if (widget.flag == "Cut") {
        callApiUserProfile();
      } else {
        callApiVideoCallToken();
      }
  }


  String? callTime = "";
  String? callDate = "";
  int? callDuration = 0;

  Future<void> setupVideoSDKEngine() async {
    // retrieve or request camera and microphone permissions
    await [Permission.microphone, Permission.camera].request();

    //create an instance of the Agora engine
    agoraEngine = createAgoraRtcEngine();
      await agoraEngine.initialize(RtcEngineContext(
      appId: appId,
    ));


    await agoraEngine.enableVideo();

    // Register the event handler
    agoraEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          showMessage("Local user uid:${connection.localUid} joined the channel");
          setState(() {
            _isJoined = true;
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (widget.flag == "InComming") {
            setState(() {
              _remoteUid = uid;
              DateTime now = DateTime.now();
              callTime = DateFormat('h:mm a').format(now);
              callDate = DateFormat('yyyy-MM-dd').format(now);
            });
          } else if (widget.flag == "Cut") {
            setState(() {
              agoraEngine.leaveChannel();
            });
          } else {
            print("remote user $uid joined");
            setState(() {
              _remoteUid = remoteUid;
            });
          }
          showMessage("Remote user uid:$remoteUid joined the channel");
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
          showMessage("Remote user uid:$remoteUid left the channel");
          setState(() {
            _remoteUid = null;
            agoraEngine.leaveChannel();
            Fluttertoast.showToast(msg: "Call Ended", toastLength: Toast.LENGTH_SHORT);
            print("Call Cut From RemoteSide");
          });
        },
        onLeaveChannel: (connection, stats) {
          if (widget.flag == "InComming") {
            setState(() {
              callDuration = stats.duration;
              if (callTime != "" && callDate != "") {
                // callApiAddVideoCallHistory();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              }
            });
          } else if (widget.flag == "Cut") {
            setState(() {
              callDuration = stats.duration;
              if (callTime != "" && callDate != "") {
                // callApiAddVideoCallHistory();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              }
            });
          } else {
            setState(() {
              callDuration = stats.duration;
              OverlayService().removeVideosOverlay(context, VideoCall(doctorId: widget.doctorId));
            });
          }
        },
      ),
    );
  }

  void  join() async {
    await agoraEngine.startPreview();

    // Set channel options including the client role and channel profile
    ChannelMediaOptions options = const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
    );

    await agoraEngine.joinChannel(
        token: token,
        channelId: channelName,
        options: options,
        uid: uid,
    );
  }

  void leave() {
    setState(() {
    _isJoined = false;
    _remoteUid = null;
    });
    agoraEngine.leaveChannel();
  }

  @override
  void dispose() async {
    await agoraEngine.leaveChannel();
    agoraEngine.release();
    super.dispose();
  }

  // _isJoined ? null : () => {join()}
  // _isJoined ? () => {leave()} : null
  Offset offset = Offset.zero;
  bool _localUserJoined = false;

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
          controller: VideoViewController.remote(
          rtcEngine: agoraEngine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      );
    } else {
      if (widget.flag == "InComming") {
        return ScalingText(
          'Connecting...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      } else if (widget.flag == "Cut") {
        return ScalingText(
          'Call Ended...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      } else {
        return ScalingText(
          'Ringing...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      }
    }
  }

  bool muted = false;
  bool mutedVideo = false;

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return PIPView(
      builder: (context, isFloating) {
        return Scaffold(
          body: Consumer<OverlayHandlerProvider>(
            builder: (context, overlayProvider, _) {
              return InkWell(
                onTap: () {
                  Provider.of<OverlayHandlerProvider>(context, listen: false).disablePip();
                },
                child: Stack(
                  children: [
                    Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: _remoteVideo(),
                      ),
                    ),
                    widget.flag == "Cut"
                        ? Container()
                        : Stack(
                            children: [
                              Positioned(
                                left: offset.dx,
                                top: offset.dy,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      if (offset.dx > 0.0 && (offset.dx + 150) < width && offset.dy > 0.0 && (offset.dy + 200) < height) {
                                        offset = Offset(offset.dx + details.delta.dx, offset.dy + details.delta.dy);
                                      } else {
                                        offset = Offset(details.delta.dx + 20, details.delta.dy + 50);
                                      }
                                    });
                                  },
                                  child: Consumer<OverlayHandlerProvider>(
                                    builder: (context, overlayProvider, _) {
                                      return SizedBox(
                                        width: overlayProvider.inPipMode == true ? 80 : 150,
                                        height: overlayProvider.inPipMode == true ? 80 : 200,
                                        child: Center(
                                          child: _localUserJoined
                                              ? AgoraVideoView(
                                                    controller: VideoViewController(
                                                    rtcEngine: agoraEngine,
                                                    canvas: VideoCanvas(uid: 0),
                                                  ),
                                                )
                                              : const CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                    _toolbar(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    return Consumer<OverlayHandlerProvider>(
      builder: (context, overlayProvider, _) {
        return Container(
          alignment: Alignment.bottomCenter,
          padding: EdgeInsets.symmetric(vertical: overlayProvider.inPipMode == true ? 20 : 45),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RawMaterialButton(
                  onPressed: () {
                    setState(() {
                      muted = !muted;
                    });
                    agoraEngine.muteLocalAudioStream(muted);
                  },
                  child: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: muted ? Palette.white : Palette.blue,
                    size: overlayProvider.inPipMode == true ? 12.0 : 15.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: muted ? Palette.blue : Palette.white,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 12.0),
                ),
              ),
              Expanded(
                child: RawMaterialButton(
                  onPressed: () => agoraEngine.leaveChannel,
                  child: Icon(
                    Icons.call_end,
                    color: Palette.white,
                    size: overlayProvider.inPipMode == true ? 15.0 : 30.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Palette.red,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 15.0),
                ),
              ),
              Expanded(
                child: RawMaterialButton(
                  onPressed: agoraEngine.switchCamera,
                  child: Icon(
                    Icons.switch_camera,
                    color: Palette.blue,
                    size: overlayProvider.inPipMode == true ? 12.0 : 15.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Palette.white,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 12.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


*/

  String channelName = "testChannel";
  String token = "007eJxTYBA8yTzHkk0+uzpxQYQtz71JQn5Hz7ktjSlI3Vqjdi6Wv1WBITXFMskk0TLNwNLQwsQsxSgpMTHZNC3JMDnV2MzYxDLpf3RlakMgI8PjwzdYGRkgEMTnZihJLS5xzkjMy0vNYWAAAIb8IW4=";

  int uid = 0; // uid of the local user

  int? _remoteUid; // uid of the remote user
  bool _isJoined = false; // Indicates if the local user has joined the channel
  late RtcEngine agoraEngine; // Agora engine instance

  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey
  = GlobalKey<ScaffoldMessengerState>(); // Global key to access the scaffold


  showMessage(String message) {
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(message),
    ));
  }

  @override
  void initState() {
    super.initState();
    // Set up an instance of Agora engine
    setupVideoSDKEngine();
    // callApiVideoCallToken();
  }

  Future<void> setupVideoSDKEngine() async {
    // retrieve or request camera and microphone permissions
    await [Permission.microphone, Permission.camera].request();

    //create an instance of the Agora engine
    agoraEngine = createAgoraRtcEngine();
    await agoraEngine.initialize(const RtcEngineContext(
        appId: "ed9b4a9f091846d2baac5fb1ce36349b"
    ));

    await agoraEngine.enableVideo();

    // Register the event handler
    agoraEngine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          showMessage("Local user uid:${connection.localUid} joined the channel");
          setState(() {
            _isJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          showMessage("Remote user uid:$remoteUid joined the channel");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          showMessage("Remote user uid:$remoteUid left the channel");
          setState(() {
            _remoteUid = null;
          });
        },
      ),
    );
  }

  void  join() async {
    await agoraEngine.startPreview();

    // Set channel options including the client role and channel profile
    ChannelMediaOptions options = const ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    );

    await agoraEngine.joinChannel(
      token: token,
      channelId: channelName,
      options: options,
      uid: uid,
    );
  }

  void leave() {
    setState(() {
      _isJoined = false;
      _remoteUid = null;
    });
    agoraEngine.leaveChannel();
  }

  // Release the resources when you leave
  @override
  void dispose() async {
    await agoraEngine.leaveChannel();
    agoraEngine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get started with Video Calling'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // Container for the local video
          Container(
            height: 240,
            decoration: BoxDecoration(border: Border.all()),
            child: Center(child: _localPreview()),
          ),
          const SizedBox(height: 10),
          //Container for the Remote video
          Container(
            height: 240,
            decoration: BoxDecoration(border: Border.all()),
            child: Center(child: _remoteVideo()),
          ),
          // Button Row
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  onPressed: _isJoined ? null : () => {join()},
                  child: const Text("Join"),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isJoined ? () => {leave()} : null,
                  child: const Text("Leave"),
                ),
              ),
            ],
          ),
          // Button Row ends
        ],
      ),
    );
  }

  // Display local video preview
  Widget _localPreview() {
    if (_isJoined) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: agoraEngine,
          canvas: VideoCanvas(uid: 0),
        ),
      );
    } else {
      return const Text(
        'Join a channel',
        textAlign: TextAlign.center,
      );
    }

  }

  // Display remote user's video
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: agoraEngine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: channelName),
        ),
      );
    } else {
      String msg = '';
      if (_isJoined) msg = 'Waiting for a remote user to join';
      return Text(
        msg,
        textAlign: TextAlign.center,
      );
    }
  }

  Future<BaseModel<VideoCallModel>> callApiVideoCallToken() async {
    VideoCallModel response;
    Map<String, dynamic> body = {
      "to_id": widget.doctorId,
    };
    try {
      response = await RestClient(RetroApi().dioData()).videoCallRequest(body);
      if (response.success == true) {
        if(response.data?.cn != null && response.data?.token != null)
          channelName = response.data!.cn!;
          token = response.data!.token!;
          setState(() {});
      }
    } catch (error, stacktrace) {
      print("Exception occur: $error stackTrace: $stacktrace");
      return BaseModel()..setException(ServerError.withError(error: error));
    }
    return BaseModel()..data = response;
  }

  Future<BaseModel<UserDetail>> callApiUserProfile() async {
    UserDetail response;
    try {
      response = await RestClient(RetroApi().dioData()).userDetailRequest();
      setState(() {
        channelName = response.channelName!;
        token = response.agoraToken!;
      });
    } catch (error, stacktrace) {
      print("Exception occur: $error stackTrace: $stacktrace");
      return BaseModel()..setException(ServerError.withError(error: error));
    }
    return BaseModel()..data = response;
  }
}
/*
  int? _remoteUid;
  bool _localUserJoined = false;
  bool muted = false;
  bool mutedVideo = false;
  late RtcEngine _engine;
  String? appId = SharedPreferenceHelper.getString(Preferences.agoraAppId);
  String? token = "";
  String? channelName = "";
  int? callDuration = 0;
  bool? timeOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.flag == "InComming") {
      callApiUserProfile();
    } else if (widget.flag == "Cut") {
      callApiUserProfile();
    } else {
      callApiVideoCallToken();
    }
    offset = const Offset(20.0, 50.0);
  }

  Offset offset = Offset.zero;

  Widget _toolbar() {
    return Consumer<OverlayHandlerProvider>(
      builder: (context, overlayProvider, _) {
        return Container(
          alignment: Alignment.bottomCenter,
          padding: EdgeInsets.symmetric(vertical: overlayProvider.inPipMode == true ? 20 : 45),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: RawMaterialButton(
                  onPressed: _onToggleMute,
                  child: Icon(
                    muted ? Icons.mic_off : Icons.mic,
                    color: muted ? Palette.white : Palette.blue,
                    size: overlayProvider.inPipMode == true ? 12.0 : 15.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: muted ? Palette.blue : Palette.white,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 12.0),
                ),
              ),
              Expanded(
                child: RawMaterialButton(
                  onPressed: () => _onCallEnd(context),
                  child: Icon(
                    Icons.call_end,
                    color: Palette.white,
                    size: overlayProvider.inPipMode == true ? 15.0 : 30.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Palette.red,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 15.0),
                ),
              ),
              Expanded(
                child: RawMaterialButton(
                  onPressed: _onSwitchCamera,
                  child: Icon(
                    Icons.switch_camera,
                    color: Palette.blue,
                    size: overlayProvider.inPipMode == true ? 12.0 : 15.0,
                  ),
                  shape: const CircleBorder(),
                  elevation: 2.0,
                  fillColor: Palette.white,
                  padding: EdgeInsets.all(overlayProvider.inPipMode == true ? 5.0 : 12.0),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String? callTime = "";
  String? callDate = "";

  void _onCallEnd(BuildContext context) {
    _engine.leaveChannel();
  }

  void _onToggleMute() {
    setState(() {
      muted = !muted;
    });
    _engine.muteLocalAudioStream(muted);
  }

  void _onSwitchCamera() {
    _engine.switchCamera();
  }

  Future<void> initAgora() async {
    // retrieve permissions
    await [Permission.microphone, Permission.camera].request();

    //create the engine
    _engine = await RtcEngine.create(appId!);
    await _engine.enableVideo();
    _engine.setEventHandler(
      RtcEngineEventHandler(
        joinChannelSuccess: (String channel, int uid, int elapsed) {
          print("local user $uid joined");
          setState(() {
            _localUserJoined = true;
          });
        },
        userJoined: (int uid, int elapsed) {
          if (widget.flag == "InComming") {
            setState(() {
              _remoteUid = uid;
              DateTime now = DateTime.now();
              callTime = DateFormat('h:mm a').format(now);
              callDate = DateFormat('yyyy-MM-dd').format(now);
            });
          } else if (widget.flag == "Cut") {
            setState(() {
              _engine.leaveChannel();
            });
          } else {
            print("remote user $uid joined");
            setState(() {
              _remoteUid = uid;
            });
          }
        },
        userOffline: (int uid, UserOfflineReason reason) {
          print("remote user $uid left channel");
          setState(() {
            _remoteUid = null;
            _engine.leaveChannel();
            Fluttertoast.showToast(msg: "Call Ended", toastLength: Toast.LENGTH_SHORT);
            print("Call Cut From RemoteSide");
          });
        },
        leaveChannel: (RtcStats detail) {
          if (widget.flag == "InComming") {
            setState(() {
              callDuration = detail.duration;
              if (callTime != "" && callDate != "") {
                // callApiAddVideoCallHistory();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              }
            });
          } else if (widget.flag == "Cut") {
            setState(() {
              callDuration = detail.duration;
              if (callTime != "" && callDate != "") {
                // callApiAddVideoCallHistory();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => Home()),
                );
              }
            });
          } else {
            setState(() {
              callDuration = detail.duration;
              OverlayService().removeVideosOverlay(context, VideoCall(doctorId: widget.doctorId));
            });
          }
        },
      ),
    );
    await _engine.joinChannel(token, channelName!, null, 0);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return PIPView(
      builder: (context, isFloating) {
        return Scaffold(
          body: Consumer<OverlayHandlerProvider>(
            builder: (context, overlayProvider, _) {
              return InkWell(
                onTap: () {
                  Provider.of<OverlayHandlerProvider>(context, listen: false).disablePip();
                },
                child: Stack(
                  children: [
                    Container(
                      color: Colors.grey.shade300,
                      child: Center(
                        child: _remoteVideo(),
                      ),
                    ),
                    widget.flag == "Cut"
                        ? Container()
                        : Stack(
                            children: [
                              Positioned(
                                left: offset.dx,
                                top: offset.dy,
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    setState(() {
                                      if (offset.dx > 0.0 && (offset.dx + 150) < width && offset.dy > 0.0 && (offset.dy + 200) < height) {
                                        offset = Offset(offset.dx + details.delta.dx, offset.dy + details.delta.dy);
                                      } else {
                                        offset = Offset(details.delta.dx + 20, details.delta.dy + 50);
                                      }
                                    });
                                  },
                                  child: Consumer<OverlayHandlerProvider>(
                                    builder: (context, overlayProvider, _) {
                                      return SizedBox(
                                        width: overlayProvider.inPipMode == true ? 80 : 150,
                                        height: overlayProvider.inPipMode == true ? 80 : 200,
                                        child: Center(
                                          child: _localUserJoined
                                              ? RtcLocalView.SurfaceView(
                                                  renderMode: VideoRenderMode.FILL,
                                                )
                                              : const CircularProgressIndicator(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                    _toolbar(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return RtcRemoteView.SurfaceView(uid: _remoteUid!, channelId: channelName!);
    } else {
      if (widget.flag == "InComming") {
        return ScalingText(
          'Connecting...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      } else if (widget.flag == "Cut") {
        return ScalingText(
          'Call Ended...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      } else {
        return ScalingText(
          'Ringing...',
          style: TextStyle(fontSize: 16, color: Palette.dark_blue),
        );
      }
    }
  }

  Future<BaseModel<VideoCallModel>> callApiVideoCallToken() async {
    VideoCallModel response;
    Map<String, dynamic> body = {
      "to_id": widget.doctorId,
    };
    try {
      response = await RestClient(RetroApi().dioData()).videoCallRequest(body);
      if (response.success == true) {
        setState(
          () {
            channelName = response.data!.cn;
            token = response.data!.token;
            initAgora();
          },
        );
      }
    } catch (error, stacktrace) {
      print("Exception occur: $error stackTrace: $stacktrace");
      return BaseModel()..setException(ServerError.withError(error: error));
    }
    return BaseModel()..data = response;
  }

  Future<BaseModel<UserDetail>> callApiUserProfile() async {
    UserDetail response;
    try {
      response = await RestClient(RetroApi().dioData()).userDetailRequest();
      setState(() {
        channelName = response.channelName!;
        token = response.agoraToken;
        initAgora();
      });
    } catch (error, stacktrace) {
      print("Exception occur: $error stackTrace: $stacktrace");
      return BaseModel()..setException(ServerError.withError(error: error));
    }
    return BaseModel()..data = response;
  }
}
*/
* */