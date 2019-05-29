'##COPYRIGHT HEADER##

sub main(externalParams)

  port = createObject("roMessagePort")
  screen = createObject("roSGScreen")
  screen.setMessagePort(port)

  m.global = screen.getGlobalNode()
  m.global.observeField("redData", port)

  m.input = createObject("roInput")
  m.input.setMessagePort(port)

  device = createObject("roDeviceInfo")
  device.setMessagePort(port)
  device.enableLinkStatusEvent(true)


  scene = screen.createScene("Main")
  screen.show()

  scene.observeField("exitApplication", port)
  scene.observeField("sessionLength", port)

  while(true)
    msg = wait(0, port)
    msgType = type(msg)

    if invalid <> msg
      if "roInputEvent" = msgType
        info = msg.getInfo()
        if invalid <> info
          mediaType = externalParams.mediaType
          contentId = externalParams.contentId
        end if
      end if
    end if
  end while
end sub
