/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <UI/TableCells/NXProjectTableCell.h>
#import <LindChain/Project/NXProject.h>

@interface NXProjectTableCell ()

@property (nonatomic, strong, readwrite) UIImageView *customImageView;
@property (nonatomic, strong, readwrite) UILabel *customTitleLabel;
@property (nonatomic, strong, readwrite) UILabel *customDetailLabel;

@property (nonatomic, strong) NSLayoutConstraint *titleCenterYConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleTopConstraint;

@property (nonatomic, strong) NSLayoutConstraint *titleLeadingWithImageConstraint;
@property (nonatomic, strong) NSLayoutConstraint *titleLeadingWithoutImageConstraint;

@property (nonatomic, strong) NSLayoutConstraint *detailLeadingWithImageConstraint;
@property (nonatomic, strong) NSLayoutConstraint *detailLeadingWithoutImageConstraint;

@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *imageConstraints;

@end

@implementation NXProjectTableCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if(self)
    {
        [self setupViews];
        [self setupConstraints];
    }
    return self;
}

- (void)setupViews
{
    // Hide standard views to avoid interference
    self.textLabel.hidden = YES;
    self.detailTextLabel.hidden = YES;
    self.imageView.hidden = YES;

    self.customImageView = [[UIImageView alloc] init];
    self.customImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.customImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.customImageView.clipsToBounds = YES;
    self.customImageView.layer.borderWidth = 0.5;
    self.customImageView.layer.borderColor = UIColor.grayColor.CGColor;
    if (@available(iOS 26.0, *)) {
        self.customImageView.layer.cornerRadius = 15;
    } else {
        self.customImageView.layer.cornerRadius = 10;
    }
    [self.contentView addSubview:self.customImageView];

    self.customTitleLabel = [[UILabel alloc] init];
    self.customTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.customTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    self.customTitleLabel.numberOfLines = 1;
    self.customTitleLabel.textColor = [UIColor labelColor];
    [self.contentView addSubview:self.customTitleLabel];

    self.customDetailLabel = [[UILabel alloc] init];
    self.customDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.customDetailLabel.font = [UIFont systemFontOfSize:10];
    self.customDetailLabel.numberOfLines = 1;
    self.customDetailLabel.textColor = [UIColor secondaryLabelColor];
    [self.contentView addSubview:self.customDetailLabel];

    self.separatorInset = UIEdgeInsetsZero;
    self.layoutMargins = UIEdgeInsetsZero;
    self.preservesSuperviewLayoutMargins = NO;
}

- (void)setupConstraints
{
    CGFloat imageSize = 50;

    self.imageConstraints = @[
        [self.customImageView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.customImageView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [self.customImageView.widthAnchor constraintEqualToConstant:imageSize],
        [self.customImageView.heightAnchor constraintEqualToConstant:imageSize]
    ];
    [NSLayoutConstraint activateConstraints:self.imageConstraints];

    self.titleLeadingWithImageConstraint = [self.customTitleLabel.leadingAnchor constraintEqualToAnchor:self.customImageView.trailingAnchor constant:16];
    self.titleLeadingWithoutImageConstraint = [self.customTitleLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];

    self.detailLeadingWithImageConstraint = [self.customDetailLabel.leadingAnchor constraintEqualToAnchor:self.customImageView.trailingAnchor constant:16];
    self.detailLeadingWithoutImageConstraint = [self.customDetailLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16];

    self.titleCenterYConstraint = [self.customTitleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor];
    self.titleTopConstraint = [self.customTitleLabel.topAnchor constraintEqualToAnchor:self.contentView.centerYAnchor constant:-10];

    [NSLayoutConstraint activateConstraints:@[
        [self.customTitleLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.customDetailLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [self.customDetailLabel.topAnchor constraintEqualToAnchor:self.customTitleLabel.bottomAnchor constant:4]
    ]];
}

- (void)configureWithDisplayName:(NSString*)displayName
            withBundleIdentifier:(NSString*)bundleIdentifier
                     withAppIcon:(UIImage*)image
                     showAppIcon:(BOOL)showAppIcon
                    showBundleID:(BOOL)showBundleID
                       showArrow:(BOOL)showArrow
{
    // Clean up before configuring
    [self resetConstraints];

    self.customTitleLabel.text = displayName;
    self.customImageView.image = image ?: [UIImage imageNamed:@"DefaultIcon"];
    self.accessoryType = showArrow ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;

    if (showBundleID) {
        self.customDetailLabel.text = bundleIdentifier;
        self.customDetailLabel.hidden = NO;
        self.titleCenterYConstraint.active = NO;
        self.titleTopConstraint.active = YES;
    } else {
        self.customDetailLabel.text = nil;
        self.customDetailLabel.hidden = YES;
        self.titleTopConstraint.active = NO;
        self.titleCenterYConstraint.active = YES;
    }

    if (showAppIcon) {
        self.customImageView.hidden = NO;
        self.titleLeadingWithoutImageConstraint.active = NO;
        self.titleLeadingWithImageConstraint.active = YES;
        self.detailLeadingWithoutImageConstraint.active = NO;
        self.detailLeadingWithImageConstraint.active = YES;
    } else {
        self.customImageView.hidden = YES;
        self.titleLeadingWithImageConstraint.active = NO;
        self.titleLeadingWithoutImageConstraint.active = YES;
        self.detailLeadingWithImageConstraint.active = NO;
        self.detailLeadingWithoutImageConstraint.active = YES;
    }

    [self setNeedsLayout];
}

- (void)resetConstraints
{
    self.titleLeadingWithImageConstraint.active = NO;
    self.titleLeadingWithoutImageConstraint.active = NO;
    self.detailLeadingWithImageConstraint.active = NO;
    self.detailLeadingWithoutImageConstraint.active = NO;
    self.titleCenterYConstraint.active = NO;
    self.titleTopConstraint.active = NO;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.customTitleLabel.text = nil;
    self.customDetailLabel.text = nil;
    self.customImageView.image = nil;
    self.accessoryType = UITableViewCellAccessoryNone;

    self.customImageView.hidden = YES;
    self.customDetailLabel.hidden = YES;

    [self resetConstraints];
}

+ (NSString *)reuseIdentifier
{
    return @"NXProjectTableCell";
}

@end
