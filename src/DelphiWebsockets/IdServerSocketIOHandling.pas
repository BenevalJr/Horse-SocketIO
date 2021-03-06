unit IdServerSocketIOHandling;
interface
{$I wsdefines.pas}
uses
  Classes, Generics.Collections, SysUtils, StrUtils
  , System.JSON
  , IdContext
  , IdCustomTCPServer
  , IdException
  , IdServerBaseHandling
  , IdSocketIOHandling
  ;

type
  TIdServerSocketIOHandling = class(TIdBaseSocketIOHandling)
  protected
    procedure ProcessHeatbeatRequest(const AContext: ISocketIOContext; const aText: string); override;
  public
    function  SendToAll(const aMessage: string; const aCallback: TSocketIOMsgJSON = nil; const aOnError: TSocketIOError = nil): Integer;
    procedure SendTo   (const aContext: TIdServerContext; const aMessage: string; const aCallback: TSocketIOMsgJSON = nil; const aOnError: TSocketIOError = nil);
    function  EmitEventToAll(const aEventName: string; const aData: string      ; const aCallback: TSocketIOMsgJSON = nil; const aOnError: TSocketIOError = nil): Integer;overload;
    {$IFDEF SUPEROBJECT}
    function  EmitEventToAll(const aEventName: string; const aData: TJSONValue; const aCallback: TSocketIOMsgJSON = nil; const aOnError: TSocketIOError = nil): Integer;overload;
    procedure EmitEventTo   (const aContext: TIdServerContext;
                             const aEventName: string; const aData: TJSONValue; const aCallback: TSocketIOMsgJSON = nil; const aOnError: TSocketIOError = nil);overload;
    procedure EmitEventTo   (const aContext: ISocketIOContext;
                             const aEventName: string; const aData: TJSONValue; const aCallback: TSocketIOMsgJSON = nil; const aOnError: TSocketIOError = nil);overload;
    {$ENDIF}
  end;

implementation

{ TIdServerSocketIOHandling }

procedure TIdServerSocketIOHandling.ProcessHeatbeatRequest(
  const AContext: ISocketIOContext; const aText: string);
begin
  inherited ProcessHeatbeatRequest(AContext, aText);
end;

{$IFDEF SUPEROBJECT}
procedure TIdServerSocketIOHandling.EmitEventTo(
  const aContext: ISocketIOContext; const aEventName: string;
  const aData: TJSONValue; const aCallback: TSocketIOMsgJSON; const aOnError: TSocketIOError);
var
  jsonarray: string;
begin
  if aContext.IsDisconnected then
    raise EIdSocketIoUnhandledMessage.Create('socket.io connection closed!');

  jsonarray := aData.ToString;

  if not Assigned(aCallback) then
    WriteSocketIOEvent(aContext, ''{no room}, aEventName, jsonarray, nil, nil)
  else
    WriteSocketIOEventRef(aContext, ''{no room}, aEventName, jsonarray,
      procedure(const aData: string)
      begin
        aCallback(aContext, TJSONObject.ParseJSONValue(aData), nil);
      end, aOnError);
end;

procedure TIdServerSocketIOHandling.EmitEventTo(
  const aContext: TIdServerContext; const aEventName: string;
  const aData: TJSONValue; const aCallback: TSocketIOMsgJSON; const aOnError: TSocketIOError);
var
  context: ISocketIOContext;
begin
  Lock;
  try
    context := FConnections.Items[aContext];
    EmitEventTo(context, aEventName, aData, aCallback, aOnError);
  finally
    UnLock;
  end;
end;

function TIdServerSocketIOHandling.EmitEventToAll(const aEventName: string; const aData: TJSONValue;
  const aCallback: TSocketIOMsgJSON; const aOnError: TSocketIOError): Integer;
begin
  Result := EmitEventToAll(aEventName, aData.ToString, aCallback, aOnError);
end;
{$ENDIF}

function TIdServerSocketIOHandling.EmitEventToAll(const aEventName,
  aData: string; const aCallback: TSocketIOMsgJSON;
  const aOnError: TSocketIOError): Integer;
var
  context: ISocketIOContext;
  jsonarray: string;
begin
  Result := 0;
  jsonarray := '[' + aData + ']';

  Lock;
  try
    for context in FConnections.Values do
    begin
      if context.IsDisconnected then Continue;

      try
        if not Assigned(aCallback) then
          WriteSocketIOEvent(context, ''{no room}, aEventName, jsonarray, nil, nil)
        else
          WriteSocketIOEventRef(context, ''{no room}, aEventName, jsonarray,
            procedure(const aData: string)
            begin
              aCallback(context, TJSONObject.ParseJSONValue(aData), nil);
            end, aOnError);
      except
        //try to send to others
      end;
      Inc(Result);
    end;
    for context in FConnectionsGUID.Values do
    begin
      if context.IsDisconnected then Continue;

      try
        if not Assigned(aCallback) then
          WriteSocketIOEvent(context, ''{no room}, aEventName, jsonarray, nil, nil)
        else
          WriteSocketIOEventRef(context, ''{no room}, aEventName, jsonarray,
            procedure(const aData: string)
            begin
              aCallback(context, TJSONObject.ParseJSONValue(aData), nil);
            end, aOnError);
      except
        //try to send to others
      end;
      Inc(Result);
    end;
  finally
    UnLock;
  end;
end;

procedure TIdServerSocketIOHandling.SendTo(const aContext: TIdServerContext;
  const aMessage: string; const aCallback: TSocketIOMsgJSON; const aOnError: TSocketIOError);
var
  context: ISocketIOContext;
begin
  Lock;
  try
    context := FConnections.Items[aContext];
    if context.IsDisconnected then
      raise EIdSocketIoUnhandledMessage.Create('socket.io connection closed!');

    if not Assigned(aCallback) then
      WriteSocketIOMsg(context, ''{no room}, aMessage, nil)
    else
      WriteSocketIOMsg(context, ''{no room}, aMessage,
        procedure(const aData: string)
        begin
          aCallback(context, TJSONObject.ParseJSONValue(aData), nil);
        end, aOnError);
  finally
    UnLock;
  end;
end;

function TIdServerSocketIOHandling.SendToAll(const aMessage: string;
  const aCallback: TSocketIOMsgJSON; const aOnError: TSocketIOError): Integer;
var
  context: ISocketIOContext;
begin
  Result := 0;
  Lock;
  try
    for context in FConnections.Values do
    begin
      if context.IsDisconnected then Continue;

      if not Assigned(aCallback) then
        WriteSocketIOMsg(context, ''{no room}, aMessage, nil)
      else
        WriteSocketIOMsg(context, ''{no room}, aMessage,
          procedure(const aData: string)
          begin
            aCallback(context, TJSONObject.ParseJSONValue(aData), nil);
          end, aOnError);
      Inc(Result);
    end;
    for context in FConnectionsGUID.Values do
    begin
      if context.IsDisconnected then Continue;

      if not Assigned(aCallback) then
        WriteSocketIOMsg(context, ''{no room}, aMessage, nil)
      else
        WriteSocketIOMsg(context, ''{no room}, aMessage,
          procedure(const aData: string)
          begin
            aCallback(context, TJSONObject.ParseJSONValue(aData), nil);
          end);
      Inc(Result);
    end;
  finally
    UnLock;
  end;
end;

end.
