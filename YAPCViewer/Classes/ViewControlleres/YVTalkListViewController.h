//
//  YVTalkListViewController.h
//  YAPCViewer
//
//  Created by kshuin on 8/3/13.
//  Copyright (c) 2013 www.huin-lab.com. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface YVTalkListViewController : UIViewController
<UITableViewDataSource,
 UITableViewDelegate>

- (UITableView *)tableView;

@end
