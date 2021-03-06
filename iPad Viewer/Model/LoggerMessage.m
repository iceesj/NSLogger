/*
 *
 * Modified BSD license.
 *
 * Based on source code copyright (c) 2010-2012 Florent Pillet,
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * 3. Any redistribution is done solely for personal benefit and not for any
 *    commercial purpose or for monetary gain
 *
 * 4. No binary form of source code is submitted to App Store℠ of Apple Inc.
 *
 * 5. Neither the name of the Sung-Taek, Kim nor the names of its contributors
 *    may be used to endorse or promote products derived from  this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER AND AND CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 */

#import <objc/runtime.h>
#include <sys/time.h>
#import "LoggerMessage.h"
#import "LoggerConnection.h"
#import "NullStringCheck.h"

#import "LoggerMessageFormatter.h"

#import "LoggerMessageSize.h"
#import "LoggerClientSize.h"
#import "LoggerMarkerSize.h"

@implementation LoggerMessage
@synthesize tag, message, threadID;
@synthesize type, contentsType, level, timestamp;
@synthesize parts;
@synthesize image, imageSize;
@synthesize sequence;
@synthesize timestampString = _timestampString;
@synthesize filename, functionName, lineNumber;
@synthesize textRepresentation = _textRepresentation;
@synthesize truncated = _truncated;


@dynamic messageText;
@dynamic messageType;

@dynamic portraitHeight;
@dynamic portraitMessageSize;
@dynamic portraitHintSize;

@dynamic landscapeHeight;
@dynamic landscapeMessageSize;
@dynamic landscapeHintSize;

- (id) init
{
	self = [super init];
	if (self != nil)
	{
		_portraitMessageSize = _landscapeMessageSize = CGSizeZero;
		_portraitHintSize = _landscapeHintSize = CGSizeZero;
		_truncated = NO;
	}
	return self;
}

- (void)dealloc
{
	[tag release];
	[filename release];
	[functionName release];
	[parts release];
	[message release];
	[image release];
	[threadID release];
	[_timestampString release];
	[_textRepresentation release];
	[super dealloc];
}

- (UIImage *)image
{
	if (contentsType != kMessageImage)
		return nil;
	if (image == nil)
		image = [[UIImage alloc] initWithData:message];
	return image;
}

- (CGSize)imageSize
{
	if (imageSize.width == 0 || imageSize.height == 0)
		imageSize = self.image.size;
	return imageSize;
}

// -----------------------------------------------------------------------------
#pragma mark - Message Format
// -----------------------------------------------------------------------------
- (void)formatMessage
{
	switch (type) {
		case LOGMSG_TYPE_CLIENTINFO:{
			NSString *formattedMessage = \
				[LoggerMessageFormatter
				 formatClientInfoMessage:self];
			[formattedMessage retain];

			// set message body
			[_textRepresentation release],_textRepresentation = nil;
			_textRepresentation = formattedMessage;

			threadID = nil;
			_truncated = NO;

			// initially compute sizes before storage in CoreData
			[self portraitMessageSize];
			[self landscapeMessageSize];
			break;
		}

		case LOGMSG_TYPE_DISCONNECT:{
			NSString *formattedMessage =
				[LoggerMessageFormatter
				 formatAndTruncateDisplayMessage:self
				 truncated:&_truncated];
			[formattedMessage retain];

			// set message body
			[_textRepresentation release],_textRepresentation = nil;
			_textRepresentation = formattedMessage;
			
			threadID = nil;
			_truncated = NO;
			
			// initially compute sizes before storage in CoreData
			[self portraitMessageSize];
			[self landscapeMessageSize];
			break;
		}
			
		default:{
			// message format
			NSString *formattedMessage =
				[LoggerMessageFormatter
				 formatAndTruncateDisplayMessage:self
				 truncated:&_truncated];
			[formattedMessage retain];

			// set message body
			[_textRepresentation release],_textRepresentation = nil;
			_textRepresentation = formattedMessage;
			
			// in case image message, preload image
			if(contentsType == kMessageImage){
				[self image];
			}

			// initially compute sizes before storage in CoreData
			[self portraitMessageSize];
			[self landscapeMessageSize];

			if(_truncated)
			{
				[self portraitHintSize];
				[self landscapeHintSize];
			}
			
			break;
		}
	}
	
	// set timestamp string
	NSString *ts = [LoggerMessageFormatter formatTimestamp:&timestamp];
	[ts retain];
	[_timestampString release],_timestampString = nil;
	_timestampString = ts;
}

- (NSString *)messageText
{
	if (contentsType == kMessageString)
		return message;
	return nil;
}

- (NSString *)messageType
{
	if (contentsType == kMessageString)
		return @"text";
	if (contentsType == kMessageData)
		return @"data";
	return @"img";
}



//------------------------------------------------------------------------------
#pragma mark - Message size
//------------------------------------------------------------------------------
-(CGFloat)portraitHeight
{
	CGFloat height = _portraitMessageSize.height;
	
	if(_truncated)
	{
		height += _portraitHintSize.height;
	}
	
	height += MSG_CELL_TOP_BOTTOM_PADDING;
	return height;
}

-(CGSize)portraitMessageSize
{
	if(CGSizeEqualToSize(_portraitMessageSize, CGSizeZero))
	{
		CGSize size;
		CGFloat maxWidth = \
			MSG_CELL_PORTRAIT_WIDTH-(TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_SIDE_PADDING);
		
		CGFloat maxHeight = MSG_CELL_PORTRAIT_MAX_HEIGHT;
		if(_truncated)
		{
			maxHeight -= MSG_CELL_TOP_PADDING;
		}
		else
		{
			maxHeight -= MSG_CELL_TOP_BOTTOM_PADDING;
		}
		
		switch (self.type)
		{
			case LOGMSG_TYPE_LOG:
			case LOGMSG_TYPE_BLOCKSTART:
			case LOGMSG_TYPE_BLOCKEND:
				size = [LoggerMessageSize
						sizeOfMessage:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;

			case LOGMSG_TYPE_CLIENTINFO:
			case LOGMSG_TYPE_DISCONNECT:
				size = [LoggerClientSize
						sizeOfMessage:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;

			case LOGMSG_TYPE_MARK:
				size = [LoggerMarkerSize
						sizeOfMessage:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;

			default:
				size = CGSizeZero;
				break;
		}

		_portraitMessageSize = size;
	}
	
	return _portraitMessageSize;
}

-(CGSize)portraitHintSize
{
	if(CGSizeEqualToSize(_portraitHintSize, CGSizeZero))
	{
		
		CGSize size;
		CGFloat maxWidth = \
			MSG_CELL_PORTRAIT_WIDTH-(TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_SIDE_PADDING);
		CGFloat maxHeight = MSG_CELL_PORTRAIT_MAX_HEIGHT - MSG_CELL_TOP_PADDING;
		
		switch (self.type)
		{
			case LOGMSG_TYPE_LOG:
			case LOGMSG_TYPE_BLOCKSTART:
			case LOGMSG_TYPE_BLOCKEND:{
				size = [LoggerMessageSize
						sizeOfHint:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;
			}
			default:
				size = CGSizeZero;
				break;
		}
		
		_portraitHintSize = size;
	}
	
	return _portraitHintSize;
}

-(CGFloat)landscapeHeight
{
	CGFloat height = _landscapeMessageSize.height;
	
	if(_truncated)
	{
		height += _landscapeHintSize.height;
	}
	
	height += MSG_CELL_TOP_BOTTOM_PADDING;
	return height;
}

-(CGSize)landscapeMessageSize
{
	if(CGSizeEqualToSize(_landscapeMessageSize, CGSizeZero))
	{
		CGSize size;
		CGFloat maxWidth = \
			MSG_CELL_LANDSCAPE_WDITH-(TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_SIDE_PADDING);
		
		CGFloat maxHeight = MSG_CELL_LANDSCALE_MAX_HEIGHT;

		if(_truncated)
		{
			maxHeight -= MSG_CELL_TOP_PADDING;
		}
		else
		{
			maxHeight -= MSG_CELL_TOP_BOTTOM_PADDING;
		}
			

		switch (self.type)
		{
			case LOGMSG_TYPE_LOG:
			case LOGMSG_TYPE_BLOCKSTART:
			case LOGMSG_TYPE_BLOCKEND:{
				size = [LoggerMessageSize
						sizeOfMessage:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;
			}
			case LOGMSG_TYPE_CLIENTINFO:
			case LOGMSG_TYPE_DISCONNECT:{
				size = [LoggerClientSize
						sizeOfMessage:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;
			}
			case LOGMSG_TYPE_MARK:{
				size = [LoggerMarkerSize
						sizeOfMessage:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;
			}

			default:
				size = CGSizeZero;
				break;
		}

		_landscapeMessageSize = size;
	}

	return _landscapeMessageSize;
}

-(CGSize)landscapeHintSize
{
	if (CGSizeEqualToSize(_landscapeHintSize, CGSizeZero))
	{
		CGSize size;
		CGFloat maxWidth = \
			MSG_CELL_LANDSCAPE_WDITH-(TIMESTAMP_COLUMN_WIDTH + DEFAULT_THREAD_COLUMN_WIDTH + MSG_CELL_SIDE_PADDING);
		CGFloat maxHeight = MSG_CELL_LANDSCALE_MAX_HEIGHT - MSG_CELL_TOP_PADDING;
		
		switch (self.type)
		{
			case LOGMSG_TYPE_LOG:
			case LOGMSG_TYPE_BLOCKSTART:
			case LOGMSG_TYPE_BLOCKEND:{
				size = [LoggerMessageSize
						sizeOfHint:self
						maxWidth:maxWidth
						maxHeight:maxHeight];
				break;
			}
			default:
				break;
		}

		_landscapeHintSize = size;

	}
	
	return _landscapeHintSize;
}

// -----------------------------------------------------------------------------
#pragma mark - Other
// -----------------------------------------------------------------------------
- (void)makeTerminalMessage
{
	// Append a disconnect message for only one of the two streams
	
	gettimeofday(&timestamp, NULL);
	type = LOGMSG_TYPE_DISCONNECT;
	
	sequence = INT_MAX-2;
	message = NSLocalizedString(@"Client disconnected", @"");
	contentsType = kMessageString;
}

- (void)computeTimeDelta:(struct timeval *)td since:(LoggerMessage *)previousMessage
{
	assert(previousMessage != NULL);
	double t1 = (double)timestamp.tv_sec + ((double)timestamp.tv_usec) / 1000000.0;
	double t2 = (double)previousMessage->timestamp.tv_sec + ((double)previousMessage->timestamp.tv_usec) / 1000000.0;
	double t = t1 - t2;
	td->tv_sec = (__darwin_time_t)t;
	td->tv_usec = (__darwin_suseconds_t)((t - (double)td->tv_sec) * 1000000.0);
}

#ifdef DEBUG
-(NSString *)description
{
	NSString *typeString = ((type == LOGMSG_TYPE_LOG) ? @"Log" :
							(type == LOGMSG_TYPE_CLIENTINFO) ? @"ClientInfo" :
							(type == LOGMSG_TYPE_DISCONNECT) ? @"Disconnect" :
							(type == LOGMSG_TYPE_BLOCKSTART) ? @"BlockStart" :
							(type == LOGMSG_TYPE_BLOCKEND) ? @"BlockEnd" :
							(type == LOGMSG_TYPE_MARK) ? @"Mark" :
							@"Unknown");
	NSString *desc;
	if (contentsType == kMessageData)
		desc = [NSString stringWithFormat:@"{data %u bytes}", [message length]];
	else if (contentsType == kMessageImage)
		desc = [NSString stringWithFormat:@"{image w=%d h=%d}", (NSInteger)[self imageSize].width, (NSInteger)[self imageSize].height];
	else
		desc = (NSString *)message;
	
	return [NSString stringWithFormat:@"<%@ %p seq=%d type=%@ thread=%@ tag=%@ level=%d message=%@>",
			[self class], self, sequence, typeString, threadID, tag, (int)level, desc];
}
#endif

@end
