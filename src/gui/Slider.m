/*
 * Copyright (c) 2011 Dan Wilcox <danomatika@gmail.com>
 *
 * BSD Simplified License.
 * For information on usage and redistribution, and for a DISCLAIMER OF ALL
 * WARRANTIES, see the file, "LICENSE.txt," in this distribution.
 *
 * See https://github.com/danomatika/robotcowboy for documentation
 *
 */
#import "Slider.h"

#import "Gui.h"

@interface Slider () {}

// get scaled value based on width or height & max/min
- (float)horizontalValue:(float)x;
- (float)verticalValue:(float)y;

@end

@implementation Slider

+ (id)sliderFromAtomLine:(NSArray*)line withOrientation:(SliderOrientation)orientation withGui:(Gui*)gui {

	if(line.count < 23) { // sanity check
		DDLogWarn(@"Cannot create Slider, atom line length < 23");
		return nil;
	}

	CGRect frame = CGRectMake(
		round([[line objectAtIndex:2] floatValue] * gui.scaleX),
		round([[line objectAtIndex:3] floatValue] * gui.scaleY),
		round([[line objectAtIndex:5] floatValue] * gui.scaleX),
		round([[line objectAtIndex:6] floatValue] * gui.scaleX));

	Slider *s = [[Slider alloc] initWithFrame:frame];

	s.orientation = orientation;
	s.minValue = [[line objectAtIndex:7] floatValue];
	s.maxValue = [[line objectAtIndex:8] floatValue];
	s.log = [[line objectAtIndex:9] integerValue];
	s.inits = [[line objectAtIndex:10] boolValue];
	
	s.sendName = [gui formatAtomString:[line objectAtIndex:11]];
	s.receiveName = [gui formatAtomString:[line objectAtIndex:12]];
	if(![s hasValidSendName] && ![s hasValidReceiveName]) {
		// drop something we can't interact with
		DDLogVerbose(@"Dropping Slider, send/receive names are empty");
		return nil;
	}
	
	s.label.text = [gui formatAtomString:[line objectAtIndex:13]];
	if(![s.label.text isEqualToString:@""]) {
		s.label.font = [UIFont fontWithName:GUI_FONT_NAME size:gui.fontSize];
		[s.label sizeToFit];
		int nudgeX = 0, nudgeY = 0;
		if(orientation == SliderOrientationHorizontal) {
			nudgeX = 4;
			nudgeY = -2;
		}
		CGRect labelFrame = CGRectMake(
			round([[line objectAtIndex:14] floatValue] * gui.scaleX) + nudgeX,
			round(([[line objectAtIndex:15] floatValue] * gui.scaleY)) + nudgeY,
			s.label.frame.size.width,
			s.label.frame.size.height
		);
		s.label.frame = labelFrame;
		[s addSubview:s.label];
	}
	
	if(orientation == SliderOrientationHorizontal) {
		s.value = ([[line objectAtIndex:21] floatValue] * 0.01 * (s.maxValue - s.minValue)) /
			[[line objectAtIndex:5] floatValue];
	}
	else {
		s.value = ([[line objectAtIndex:21] floatValue] * 0.01 * (s.maxValue - s.minValue)) /
			([[line objectAtIndex:6] floatValue] - 1 + s.minValue);
	}
	
	[s sendInitValue];
	
	return s;
}

- (id)initWithFrame:(CGRect)frame {    
    self = [super initWithFrame:frame];
    if (self) {
		self.log = 0;
		self.orientation = SliderOrientationHorizontal;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {

    CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextTranslateCTM(context, 0.5, 0.5); // snap to nearest pixel
    CGContextSetStrokeColorWithColor(context, self.frameColor.CGColor);
    CGContextSetLineWidth(context, 1.0);
	
    CGRect frame = rect;
	
	// border
	CGContextStrokeRect(context, CGRectMake(0, 0, CGRectGetWidth(rect)-1, CGRectGetHeight(rect)-1));
	
	// slider pos
	CGContextSetLineWidth(context, 4.0);
	if(self.orientation == SliderOrientationHorizontal) {
		float x = round(frame.origin.x + ((self.value - self.minValue) / (self.maxValue - self.minValue)) * rect.size.width);
		CGContextMoveToPoint(context, x, round(frame.origin.y));
		CGContextAddLineToPoint(context, x, round(rect.origin.y+rect.size.height));
		CGContextStrokePath(context);
	}
	else {
		float y = round(rect.origin.y+rect.size.height - ((self.value - self.minValue) / (self.maxValue - self.minValue)) * rect.size.height);
		CGContextMoveToPoint(context, round(rect.origin.x), y);
		CGContextAddLineToPoint(context, round(rect.origin.x+rect.size.width), y);
		CGContextStrokePath(context);
	}
}

#pragma mark Overridden Getters & Setters

- (void)setValue:(float)f {
	[super setValue:MIN(self.maxValue, MAX(self.minValue, f))];
}

- (NSString*)type {
	if(self.orientation == SliderOrientationHorizontal) {
		return @"HSlider";
	}
	return @"VSlider";
}

#pragma mark Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
    UITouch *touch = [touches anyObject];
    CGPoint pos = [touch locationInView:self];
	if(self.orientation == SliderOrientationHorizontal) {
		self.value = [self horizontalValue:pos.x];
	}
	else {
		self.value = [self verticalValue:pos.y];
	}
	[self sendFloat:self.value];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint pos = [touch locationInView:self];
	if(self.orientation == SliderOrientationHorizontal) {
		self.value = [self horizontalValue:pos.x];
	}
	else {
		self.value = [self verticalValue:pos.y];
	}
	[self sendFloat:self.value];
}

#pragma mark PdListener

- (void)receiveBangFromSource:(NSString *)source {
	[self sendFloat:self.value];
}

- (void)receiveFloat:(float)received fromSource:(NSString *)source {
	self.value = received;
	[self sendFloat:self.value];
}

- (void)receiveList:(NSArray *)list fromSource:(NSString *)source {
	if(list.count > 0 && [Util isNumberIn:list at:0]) {
		[self receiveFloat:[[list objectAtIndex:0] floatValue] fromSource:source];
	}
}

- (void)receiveMessage:(NSString *)message withArguments:(NSArray *)arguments fromSource:(NSString *)source {
	if(arguments.count > 0 && [Util isNumberIn:arguments at:0]) {
		[self receiveFloat:[[arguments objectAtIndex:0] floatValue] fromSource:source];
	}
}

#pragma mark Private

- (float)horizontalValue:(float)x {
	return ((x / self.frame.size.width) * (self.maxValue - self.minValue) + self.minValue);
}

- (float)verticalValue:(float)y {
	return (((self.frame.size.height - y) / self.frame.size.height) * (self.maxValue - self.minValue) + self.minValue);
}

@end