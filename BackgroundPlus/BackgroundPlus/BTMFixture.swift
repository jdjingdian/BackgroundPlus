import Foundation

enum BTMFixture {
    static let sampleDump = """
 #14:
                 UUID: 9FD66779-F282-418B-AE30-74ABC7E26CA0
                 Name: Static Router
                 Type: app (0x2)
          Disposition: [disabled, allowed, visible, not notified] (pending authorization) (0x12)
           Identifier: 2.cn.magicdian.staticrouter
                  URL: file:///Applications/Static%20Router.app/
           Generation: 0
    Bundle Identifier: cn.magicdian.staticrouter
  Embedded Item Identifiers:
    #1: 16.cn.magicdian.staticrouter.service

 #15:
                 UUID: C682E45D-E1E5-4174-A301-7F8C05ED1627
                 Name: cn.magicdian.staticrouter.helper
                 Type: daemon (0x10)
          Disposition: [disabled, allowed, visible, not notified] (0x2)
           Identifier: 16.cn.magicdian.staticrouter.service
                  URL: Contents/Library/LaunchDaemons/cn.magicdian.staticrouter.service.plist
      Executable Path: Contents/Library/LaunchServices/cn.magicdian.staticrouter.helper
           Generation: 4
    Parent Identifier: 2.cn.magicdian.staticrouter
"""
}
