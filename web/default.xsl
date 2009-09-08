<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

	<xsl:template match="/misterhouse/groups">
		<html>
			<head>
				<link rel="stylesheet" href="/default.css" type="text/css" />
				<base target='control'></base>
			</head>

			<body>
				<ul>
					<xsl:for-each select="/misterhouse/groups/group">
						<li>
							<xsl:element name="a">
								<xsl:attribute name="href">
									<xsl:text>sub?xml(groups=</xsl:text>
									<xsl:value-of select="name"/>
									<xsl:text>)</xsl:text>
								</xsl:attribute>
								<xsl:value-of select="name"/>
							</xsl:element>
							<ul>
								<xsl:for-each select="object">
									<li>
										<xsl:element name="a">
											<xsl:attribute name="href">
												<xsl:text>sub?xml(groups=</xsl:text>
												<xsl:value-of select="name"/>
												<xsl:text>)</xsl:text>
											</xsl:attribute>
											<xsl:value-of select="name"/>
										</xsl:element>
										<ul>
											<xsl:for-each select="./*">
												<li>
													<xsl:element name="a">
														<xsl:attribute name="href">
															<xsl:text>sub?xml(groups=</xsl:text>
															<xsl:value-of select="."/>
															<xsl:text>)</xsl:text>
														</xsl:attribute>
														<xsl:value-of select="local-name()"/>: <xsl:value-of select="."/>
													</xsl:element>
												</li>
											</xsl:for-each>
										</ul>
									</li>
								</xsl:for-each>
							</ul>
						</li>
					</xsl:for-each>
				</ul>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="/misterhouse/types">
		<html>
			<head>
				<link rel="stylesheet" href="/default.css" type="text/css" />
				<base target='control'></base>
			</head>

			<body>
				<ul>
					<xsl:for-each select="/misterhouse/types/type">
						<li>
							<xsl:element name="a">
								<xsl:attribute name="href">
									<xsl:text>sub?xml(types=</xsl:text>
									<xsl:value-of select="name"/>
									<xsl:text>)</xsl:text>
								</xsl:attribute>
								<xsl:value-of select="name"/>
							</xsl:element>
							<ul>
								<xsl:for-each select="object">
									<li>
										<xsl:element name="a">
											<xsl:attribute name="href">
												<xsl:text>sub?xml(types=</xsl:text>
												<xsl:value-of select="name"/>
												<xsl:text>)</xsl:text>
											</xsl:attribute>
											<xsl:value-of select="name"/>
										</xsl:element>
										<ul>
											<xsl:for-each select="./*">
												<li>
													<xsl:element name="a">
														<xsl:attribute name="href">
															<xsl:text>sub?xml(groups=</xsl:text>
															<xsl:value-of select="."/>
															<xsl:text>)</xsl:text>
														</xsl:attribute>
														<xsl:value-of select="."/>
													</xsl:element>
												</li>
											</xsl:for-each>
										</ul>
									</li>
								</xsl:for-each>
							</ul>
						</li>
					</xsl:for-each>
				</ul>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="/misterhouse/categories">
		<html>
			<head>
				<link rel="stylesheet" href="/default.css" type="text/css" />
				<base target='control'></base>
			</head>

			<body>
				<ul>
					<xsl:for-each select="/misterhouse/categories/category">
						<li>
							<xsl:element name="a">
								<xsl:attribute name="href">
									<xsl:text>sub?xml(categories=</xsl:text>
									<xsl:value-of select="name"/>
									<xsl:text>)</xsl:text>
								</xsl:attribute>
								<xsl:value-of select="name"/>
							</xsl:element>
							<ul>
								<xsl:for-each select="object">
									<li>
										<xsl:element name="a">
											<xsl:attribute name="href">
												<xsl:text>sub?xml(categories=</xsl:text>
												<xsl:value-of select="name"/>
												<xsl:text>)</xsl:text>
											</xsl:attribute>
											<xsl:value-of select="name"/>
										</xsl:element>
										<ul>
											<xsl:for-each select="./*">
												<li>
													<xsl:element name="a">
														<xsl:attribute name="href">
															<xsl:text>sub?xml(groups=</xsl:text>
															<xsl:value-of select="."/>
															<xsl:text>)</xsl:text>
														</xsl:attribute>
														<xsl:value-of select="."/>
													</xsl:element>
												</li>
											</xsl:for-each>
										</ul>
									</li>
								</xsl:for-each>
							</ul>
						</li>
					</xsl:for-each>
				</ul>
			</body>
		</html>
	</xsl:template>

	<xsl:template match="/misterhouse/weather">
		<html>
			<head>
				<link rel="stylesheet" href="/default.css" type="text/css" />
				<base target='control'></base>
			</head>

			<body>
				<ul>
					<xsl:for-each select="/misterhouse/weather/*">
						<li>
							<xsl:element name="a">
								<xsl:attribute name="href">
									<xsl:text>sub?xml(categories=</xsl:text>
									<xsl:value-of select="name"/>
									<xsl:text>)</xsl:text>
								</xsl:attribute>
								<xsl:value-of select="local-name()"/>:
								<xsl:value-of select="."/>
							</xsl:element>
						</li>
					</xsl:for-each>
				</ul>
			</body>
		</html>
	</xsl:template>

</xsl:stylesheet>
