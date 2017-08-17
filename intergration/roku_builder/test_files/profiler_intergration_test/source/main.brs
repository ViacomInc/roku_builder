'********** Copyright 2016 Roku Corp.  All Rights Reserved. **********

sub Main(externalParams)

  screen = CreateObject("roSGScreen")
  m.port = CreateObject("roMessagePort")
  screen.setMessagePort(m.port)
  scene = screen.CreateScene("RectangleExample")
  screen.getGlobalNode().addFields({externalParams: externalParams})

  screen.show()
  while(true)
    msg = wait(0, m.port)
    msgType = type(msg)

    if msgType = "roSGScreenEvent"
      if msg.isScreenClosed() then return
    end if
  end while

end sub
