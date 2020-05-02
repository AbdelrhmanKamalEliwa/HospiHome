//
//  CardViewController.swift
//  HospiHome
//
//  Created by Elser_10 on 5/1/20.
//  Copyright © 2020 Elser_10. All rights reserved.
//

import UIKit

class CardViewController: UIViewController {
    
    @IBOutlet weak var moveAreaView: UIView!
    
    fileprivate let cellId = "cellId"
    
    lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .white
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.delegate = self
        tv.dataSource = self
        return tv
    }()
    
    let cardNames = ["Notification", "Settings", "Help", "Give us feedback", "Log out"]
    let cardIcons = ["bell.fill", "", "info", "bubble.left.fill", "arrow.left"]
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }
    
    func setupViews() {
        tableView.register(ProfileCell.self, forCellReuseIdentifier: cellId)
        
        view.addSubview(tableView)
        
        tableView.topAnchor.constraint(equalTo: view.topAnchor, constant: 70).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
    }
}

extension CardViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cardNames.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! ProfileCell
        
        cell.nameLabel.text = cardNames[indexPath.row]
        
        if indexPath.row == 1 {
            cell.imageName.image = UIImage(named: "settings")?.withRenderingMode(.alwaysTemplate)
        } else {
            cell.imageName.image = UIImage(systemName: cardIcons[indexPath.row])
        }
        
        cell.tintColor = .gray
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

