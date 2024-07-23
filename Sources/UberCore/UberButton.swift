//
//  UberButton.swift
//  UberCore
//
//  Copyright © 2024 Uber Technologies, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

open class UberButton: UIButton {
    
    // MARK: Public Properties
    
    open var title: String { "" }
    
    open var image: UIImage? { nil }
    
    // MARK: Initializers
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    // MARK: UIButton
        
    open override var isHighlighted: Bool {
        didSet { update() }
    }

    // MARK: Private
    
    private func configure() {
        contentHorizontalAlignment = .fill
        update()
    }
    
    public func update() {
        DispatchQueue.main.async { [self] in
            if #available(iOS 15, *) {
                configuration = .uber(
                    title: title,
                    image: image,
                    isHighlighted: isHighlighted
                )
                updateConfiguration()
            } 
            else {
                clipsToBounds = true
                layer.cornerRadius = Constants.cornerRadius

                setImage(
                    image?.withRenderingMode(.alwaysTemplate),
                    for: .normal
                )
                imageView?.tintColor = .uberButtonForeground
                imageView?.contentMode = .left
                
                setTitle(title, for: .normal)
                titleLabel?.textAlignment = .right
                
                setTitleColor(.uberButtonForeground, for: .normal)
                backgroundColor = isHighlighted ? .uberButtonHighlightedBackground : .uberButtonBackground
                
                contentEdgeInsets = Constants.contentInsets
            }
        }
    }
    
    private enum Constants {
        static let cornerRadius: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 10
        static let contentInsets: UIEdgeInsets = .init(top: 0, left: 16, bottom: 0, right: 16)
    }
}


@available(iOS 15, *)
extension UIButton.Configuration {
    
    static func uber(title: String? = nil,
                     image: UIImage? = nil,
                     isHighlighted: Bool = false) -> UIButton.Configuration {
        
        var style: UIButton.Configuration = .plain()
        
        // Background Color
        var background = style.background
        background.backgroundColor = isHighlighted ? .uberButtonHighlightedBackground : .uberButtonBackground
        style.background = background
        
        // Image
        style.image = image
        style.imagePadding = 12.0
        
        // Text
        style.title = title
        style.titleAlignment = .trailing
        style.baseForegroundColor = .uberButtonForeground
        
        return style
    }
}
    

/// Base class for Uber buttons that sets up colors and some constraints.
open class UberButton_DEPRECATED: UIButton {
    public let cornerRadius: CGFloat = 8
    public let horizontalEdgePadding: CGFloat = 16
    public let imageLabelPadding: CGFloat = 8
    public let verticalPadding: CGFloat = 10
    
    public let uberImageView: UIImageView = UIImageView()
    public let uberTitleLabel: UILabel = UILabel()
    
    public var colorStyle: UberButtonColorStyle = .black {
        didSet {
            colorStyleDidUpdate(colorStyle)
        }
    }
    
    override open var isHighlighted: Bool {
        didSet {
            updateColors(isHighlighted)
        }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setup()
        colorStyleDidUpdate(.black)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
        colorStyleDidUpdate(.black)
    }
    
    /**
     Function responsible for the initial setup of the button. 
     Calls addSubviews(), setContent(), and setConstraints()
     */
    open func setup() {
        addSubviews()
        setContent()
        setConstraints()
    }
    
    /**
     Function responsible for adding all the subviews to the button. Subclasses
     should override this method and add any necessary subviews.
     */
    open func addSubviews() {
        addSubview(uberImageView)
        addSubview(uberTitleLabel)
    }
    
    /**
     Function responsible for updating content on the button. Subclasses should
     override and do any necessary view setup
     */
    open func setContent() {
        clipsToBounds = true
        layer.cornerRadius = cornerRadius
    }
    
    /**
     Function responsible for adding autolayout constriants on the button. Subclasses
     should override and add any additional autolayout constraints
     */
    open func setConstraints() {
        
        uberTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        uberImageView.translatesAutoresizingMaskIntoConstraints = false
        
        let views = ["imageView": uberImageView, "titleLabel": uberTitleLabel]
        let metrics = ["edgePadding": horizontalEdgePadding, "verticalPadding": verticalPadding, "imageLabelPadding": imageLabelPadding]
        
        let horizontalConstraints = NSLayoutConstraint.constraints(withVisualFormat: "H:|-edgePadding-[imageView]-imageLabelPadding-[titleLabel]-(edgePadding)-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: metrics, views: views)
        let verticalContraints = NSLayoutConstraint.constraints(withVisualFormat: "V:|-verticalPadding-[imageView]-verticalPadding-|", options: NSLayoutConstraint.FormatOptions(rawValue: 0), metrics: metrics, views: views)
        
        addConstraints(horizontalConstraints)
        addConstraints(verticalContraints)
    }
    
    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        let logoSize = uberImageView.image?.size ?? CGSize.zero
        let titleSize = uberTitleLabel.intrinsicContentSize
        
        let width: CGFloat = 4*horizontalEdgePadding + imageLabelPadding + logoSize.width + titleSize.width
        let height: CGFloat = 2*verticalPadding + max(logoSize.height, titleSize.height)
        
        return CGSize(width: width, height: height)
    }

    open func colorStyleDidUpdate(_ style: UberButtonColorStyle) {
        switch colorStyle {
        case .black:
            backgroundColor = ColorUtil.colorForUberButtonColor(.uberBlack)
            uberTitleLabel.textColor = ColorUtil.colorForUberButtonColor(.uberWhite)
            uberImageView.tintColor = ColorUtil.colorForUberButtonColor(.uberWhite)
        case .white :
            backgroundColor = ColorUtil.colorForUberButtonColor(.uberWhite)
            uberTitleLabel.textColor = ColorUtil.colorForUberButtonColor(.uberBlack)
            uberImageView.tintColor = ColorUtil.colorForUberButtonColor(.uberBlack)
        }
    }
    
    // Mark: Private Interface
    
    private func updateColors(_ highlighted : Bool) {
        var color: UberButtonColor
        switch colorStyle {
        case .black:
            color = highlighted ? .blackHighlighted : .uberBlack
        case .white:
            color = highlighted ? .whiteHighlighted : .uberWhite
        }
        backgroundColor = ColorUtil.colorForUberButtonColor(color)
    }
}

public enum UberButtonColor: Int {
    case uberBlack
    case uberWhite
    case blackHighlighted
    case whiteHighlighted
}

public enum UberButtonColorStyle: Int {
    case black
    case white
}

public class ColorUtil {
    public static func colorForUberButtonColor(_ color: UberButtonColor) -> UIColor {
        let hexCode = hexCodeFromColor(color)
        let scanner = Scanner(string: hexCode)
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)

        let mask = 0x000000FF

        let redValue = CGFloat(Int(color >> 16)&mask)/255.0
        let greenValue = CGFloat(Int(color >> 8)&mask)/255.0
        let blueValue = CGFloat(Int(color)&mask)/255.0

        return UIColor(red: redValue, green: greenValue, blue: blueValue, alpha: 1.0)
    }

    private static func hexCodeFromColor(_ color: UberButtonColor) -> String {
        switch color {
        case .uberBlack:
            return "000000"
        case .uberWhite:
            return "FFFFFF"
        case .blackHighlighted:
            return "282727"
        case .whiteHighlighted:
            return "E5E5E4"
        }
    }
}
