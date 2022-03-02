//
//  PrivateExtensions.swift
//  MusicYa
//
//  Created by Denis Koryttsev on 02.03.2022.
//

import UIKit

protocol LazyLoadable {}
extension NSObject: LazyLoadable {}

extension LazyLoadable {
    func didLoad(_ completion: (Self) -> Void) -> Self {
        completion(self); return self
    }
    /// Kotlin-like convenience accessor to instance
    func `let`(_ closure: (Self) -> Void) -> Self {
        closure(self); return self
    }
}
extension LazyLoadable where Self: CALayer {
    func insert(to superview: UIView, at index: UInt32) -> Self {
        superview.layer.insertSublayer(self, at: index); return self
    }
    func insert(to superview: UIView, at index: UInt32, completion: (Self) -> Void) -> Self {
        superview.layer.insertSublayer(self, at: index); completion(self); return self
    }
    func insert(to superview: UIView, above: CALayer, completion: (Self) -> Void) -> Self {
        superview.layer.insertSublayer(self, above: above); completion(self); return self
    }
    func insert(to superview: UIView, below: CALayer, completion: (Self) -> Void) -> Self {
        superview.layer.insertSublayer(self, below: below); completion(self); return self
    }
    func add(to superview: UIView) -> Self {
        superview.layer.addSublayer(self); return self
    }
    func add(to superview: UIView, completion: (Self) -> Void) -> Self {
        superview.layer.addSublayer(self); completion(self); return self
    }
}
extension LazyLoadable where Self: UIView {
    func add(to superview: UIView) -> Self {
        superview.addSubview(self); return self
    }
    func add(to superview: UIView, completion: (Self) -> Void) -> Self {
        superview.addSubview(self); completion(self); return self
    }
    func insert(to superview: UIView, above: UIView, completion: (Self) -> Void) -> Self {
        superview.insertSubview(self, aboveSubview: above); completion(self); return self
    }
    func insert(to superview: UIView, below: UIView, completion: (Self) -> Void) -> Self {
        superview.insertSubview(self, belowSubview: below); completion(self); return self
    }
    func add(to superview: UIView?) -> Self {
        superview?.addSubview(self); return self
    }
    func add(to superview: UIView?, completion: (Self) -> Void) -> Self {
        superview?.addSubview(self); completion(self); return self
    }
    func insert(to superview: UIView?, above: UIView, completion: (Self) -> Void) -> Self {
        superview?.insertSubview(self, aboveSubview: above); completion(self); return self
    }
    func insert(to superview: UIView?, below: UIView, completion: (Self) -> Void) -> Self {
        superview?.insertSubview(self, belowSubview: below); completion(self); return self
    }
    func insert(to superview: UIView?, at index: Int, completion: (Self) -> Void) -> Self {
        superview?.insertSubview(self, at: index); completion(self); return self
    }
}
extension LazyLoadable where Self: UIViewController {
    func add(to superController: UIViewController) -> Self {
        superController.add(child: self)
        return self
    }
    func add(to superController: UIViewController, completion: (Self) -> Void) -> Self {
        completion(add(to: superController)); return self
    }
}
extension LazyLoadable where Self: UILayoutGuide {
    func add(to superview: UIView) -> Self {
        superview.addLayoutGuide(self); return self
    }
    func add(to superview: UIView, completion: (Self) -> Void) -> Self {
        completion(add(to: superview)); return self
    }
}

public protocol AutoLayoutItem {
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var leftAnchor: NSLayoutXAxisAnchor { get }
    var rightAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
    var widthAnchor: NSLayoutDimension { get }
    var heightAnchor: NSLayoutDimension { get }
    var centerXAnchor: NSLayoutXAxisAnchor { get }
    var centerYAnchor: NSLayoutYAxisAnchor { get }
}
public protocol BaselinedAutoLayoutItem: AutoLayoutItem {
    var firstBaselineAnchor: NSLayoutYAxisAnchor { get }
    var lastBaselineAnchor: NSLayoutYAxisAnchor { get }
}
extension AutoLayoutItem {
    public func constraints<Item: AutoLayoutItem>(equalTo item: Item, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        [
            topAnchor.constraint(equalTo: item.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(equalTo: item.bottomAnchor, constant: -edgeInsets.bottom),
            trailingAnchor.constraint(equalTo: item.trailingAnchor, constant: -edgeInsets.right),
            leadingAnchor.constraint(equalTo: item.leadingAnchor, constant: edgeInsets.left)
        ]
    }
    public func constraints<Item: AutoLayoutItem>(lessThanOrEqualTo item: Item, edgeInsets: UIEdgeInsets = .zero) -> [NSLayoutConstraint] {
        [
            topAnchor.constraint(greaterThanOrEqualTo: item.topAnchor, constant: edgeInsets.top),
            bottomAnchor.constraint(lessThanOrEqualTo: item.bottomAnchor, constant: -edgeInsets.bottom),
            trailingAnchor.constraint(lessThanOrEqualTo: item.trailingAnchor, constant: -edgeInsets.right),
            leadingAnchor.constraint(greaterThanOrEqualTo: item.leadingAnchor, constant: edgeInsets.left)
        ]
    }
    public func constraints<Item: AutoLayoutItem>(equalToCenterOf item: Item, offset: CGPoint = .zero) -> [NSLayoutConstraint] {
        [
            centerXAnchor.constraint(equalTo: item.centerXAnchor, constant: offset.x),
            centerYAnchor.constraint(equalTo: item.centerYAnchor, constant: offset.y)
        ]
    }
    public func constraints(equalToSize size: CGSize) -> [NSLayoutConstraint] {
        [
            widthAnchor.constraint(equalToConstant: size.height),
            heightAnchor.constraint(equalToConstant: size.width)
        ]
    }
    public func constraints<Item: AutoLayoutItem>(equalToSizeOf item: Item, insets: CGSize = .zero, multiplier: CGPoint = CGPoint(x: 1.0, y: 1.0)) -> [NSLayoutConstraint] {
        [
            widthAnchor.constraint(equalTo: item.widthAnchor, multiplier: multiplier.x, constant: insets.width),
            heightAnchor.constraint(equalTo: item.heightAnchor, multiplier: multiplier.y, constant: insets.height)
        ]
    }
    public func constraints<Item: AutoLayoutItem>(equalToWidthOf item: Item, multiplier: CGFloat, contant: CGFloat = 0, height: CGFloat? = nil) -> [NSLayoutConstraint] {
        [widthAnchor.constraint(equalTo: item.widthAnchor, multiplier: multiplier, constant: contant)] +
            (height.map({ [heightAnchor.constraint(equalToConstant: $0)] }) ?? [])
    }
    public func constraints<Item: AutoLayoutItem>(equalToHeightOf item: Item, multiplier: CGFloat, contant: CGFloat = 0, width: CGFloat? = nil) -> [NSLayoutConstraint] {
        [heightAnchor.constraint(equalTo: item.heightAnchor, multiplier: multiplier, constant: contant)] +
            (width.map({ [widthAnchor.constraint(equalToConstant: $0)] }) ?? [])
    }
    public func constraints<Item: AutoLayoutItem>(pinTo anchor: KeyPath<AutoLayoutItem, NSLayoutYAxisAnchor>, of item: Item, constant: CGFloat = 0) -> [NSLayoutConstraint] {
        [
            widthAnchor.constraint(equalTo: item.widthAnchor),
            centerXAnchor.constraint(equalTo: item.centerXAnchor),
            self[keyPath: anchor].constraint(equalTo: item[keyPath: anchor], constant: constant)
        ]
    }
    public func constraints<Item: AutoLayoutItem>(pinTo anchor: KeyPath<AutoLayoutItem, NSLayoutXAxisAnchor>, of item: Item, constant: CGFloat = 0) -> [NSLayoutConstraint] {
        [
            heightAnchor.constraint(equalTo: item.heightAnchor),
            centerYAnchor.constraint(equalTo: item.centerYAnchor),
            self[keyPath: anchor].constraint(equalTo: item[keyPath: anchor], constant: constant)
        ]
    }
    public func constraints<Item: AutoLayoutItem>(pinTo xAnchor: KeyPath<AutoLayoutItem, NSLayoutXAxisAnchor>, _ thisXAnchor: KeyPath<AutoLayoutItem, NSLayoutXAxisAnchor>? = nil, yAnchor: KeyPath<AutoLayoutItem, NSLayoutYAxisAnchor>, _ thisYAnchor: KeyPath<AutoLayoutItem, NSLayoutYAxisAnchor>? = nil, of item: Item, constant: CGPoint = .zero) -> [NSLayoutConstraint] {
        [
            self[keyPath: thisXAnchor ?? xAnchor].constraint(equalTo: item[keyPath: xAnchor], constant: constant.x),
            self[keyPath: thisYAnchor ?? yAnchor].constraint(equalTo: item[keyPath: yAnchor], constant: constant.y)
        ]
    }
}
extension UIView: BaselinedAutoLayoutItem {}
extension UILayoutGuide: AutoLayoutItem {}

extension CGPoint {
    func offset(dx: CGFloat, dy: CGFloat) -> CGPoint {
        var point = self
        point.x += dx; point.y += dy
        return point
    }
}
extension CGSize {
    var maxSide: CGFloat {
        return max(self.height, self.width)
    }
    var minSide: CGFloat {
        return min(self.height, self.width)
    }
    init(square size: CGFloat) {
        self.init(width: size, height: size)
    }
}
extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
    init(center: CGPoint, size: CGSize) {
        self.init(origin: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), size: size)
    }
}
extension UIEdgeInsets {
    init(horizontal: CGFloat, vertical: CGFloat) {
        self.init(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

extension UIImage {
    static func colored(by color: CGColor, opaque: Bool = false) -> UIImage {
        let rect = CGRect(origin: .zero, size: CGSize(square: 1))
        UIGraphicsBeginImageContextWithOptions(rect.size, opaque, 1)
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(color)
        context?.fill(rect)
        let returnedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return returnedImage!
    }
}

extension UIView {
    convenience init(autolayout: Bool) {
        self.init()
        translatesAutoresizingMaskIntoConstraints = !autolayout
    }
}

extension UIViewController {
    var isPresented: Bool { return presentingViewController != nil }
    var isPresenting: Bool { return presentedViewController != nil }

    func navigated() -> UINavigationController { return UINavigationController(rootViewController: self) }

    func add<T: UIViewController>(child viewController: T, sourceView: UIView? = nil, to index: Int? = nil, layoutProcess: ((UIView, UIView) -> Void)? = nil) {
        let view = sourceView ?? self.view!
        addChild(viewController)
        view.insertSubview(viewController.view, at: index ?? view.subviews.endIndex)
        layoutProcess?(view, viewController.view)
        viewController.didMove(toParent: self)
    }
    func remove<T: UIViewController>(child viewController: T) {
        viewController.willMove(toParent: nil)
        viewController.view.removeFromSuperview()
        viewController.removeFromParent()
    }
}
